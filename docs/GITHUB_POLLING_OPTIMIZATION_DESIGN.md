# GitHub APIポーリング最適化設計

## 概要

GitHub APIのレート制限を考慮しつつ、実用的な応答速度を実現するポーリング設計。

## GitHub APIレート制限

### 基本制限
- **認証済みユーザー**: 5,000 リクエスト/時間
- **エンタープライズ**: 15,000 リクエスト/時間
- **条件付きリクエスト**: レート制限にカウントされない（304 Not Modified）

### 実効レート
- 5,000 req/hour = 83 req/分 = 1.38 req/秒
- 3ワーカー使用時: 各27 req/分まで
- 安全マージン考慮: 各20 req/分を上限に

## 推奨ポーリング戦略

### 1. アダプティブポーリング

```python
class AdaptivePolling:
    def __init__(self):
        self.base_interval = 300  # 5分（デフォルト）
        self.min_interval = 60    # 1分（最短）
        self.max_interval = 900   # 15分（最長）
        self.activity_score = 0
        
    def calculate_next_interval(self, found_tasks, time_of_day):
        # アクティビティに基づく調整
        if found_tasks > 0:
            self.activity_score = min(10, self.activity_score + 2)
        else:
            self.activity_score = max(0, self.activity_score - 1)
        
        # 時間帯による調整
        hour = time_of_day.hour
        if 9 <= hour <= 18:  # 業務時間
            time_factor = 0.8
        elif 6 <= hour <= 22:  # 活動時間
            time_factor = 1.0
        else:  # 深夜
            time_factor = 2.0
        
        # 間隔計算
        interval = self.base_interval * time_factor
        
        # アクティビティによる調整
        if self.activity_score > 7:
            interval = self.min_interval
        elif self.activity_score > 4:
            interval = interval * 0.5
        elif self.activity_score < 2:
            interval = interval * 1.5
            
        return max(self.min_interval, min(self.max_interval, interval))
```

### 2. 条件付きリクエストの活用

```python
class EfficientGitHubPoller:
    def __init__(self):
        self.etag_cache = {}
        self.last_modified_cache = {}
    
    def poll_issues(self, labels):
        # 前回のETagを使用
        headers = {}
        cache_key = f"issues_{labels}"
        
        if cache_key in self.etag_cache:
            headers['If-None-Match'] = self.etag_cache[cache_key]
        
        response = self.github.get_issues(
            labels=labels,
            headers=headers
        )
        
        # 304 Not Modifiedの場合、レート制限にカウントされない
        if response.status_code == 304:
            return []  # 変更なし
        
        # 新しいETagを保存
        if 'ETag' in response.headers:
            self.etag_cache[cache_key] = response.headers['ETag']
        
        return response.json()
```

## 推奨タイミング設定

### ポーリング間隔

| 状況 | 間隔 | 理由 |
|------|------|------|
| **新規タスク発見直後** | 1分 | 関連タスクの可能性 |
| **通常（業務時間）** | 3分 | バランスの良い応答性 |
| **通常（業務時間外）** | 5分 | 標準的な間隔 |
| **アイドル（1時間活動なし）** | 10分 | リソース節約 |
| **深夜（0-6時）** | 15分 | 最小限のチェック |

### 実装例

```python
import time
from datetime import datetime, timedelta

class SmartPoller:
    def __init__(self, worker_name):
        self.worker_name = worker_name
        self.last_activity = None
        self.consecutive_empty_polls = 0
        self.daily_request_count = 0
        self.hourly_request_count = 0
        self.hour_start = datetime.now()
        
    def get_polling_interval(self):
        now = datetime.now()
        
        # APIレート制限チェック
        if self.hourly_request_count >= 1500:  # 安全マージン
            # レート制限に近い場合は長めの間隔
            return 600  # 10分
        
        # 最近の活動チェック
        if self.last_activity:
            time_since_activity = (now - self.last_activity).seconds
            if time_since_activity < 300:  # 5分以内に活動
                return 60  # 1分間隔
            elif time_since_activity < 1800:  # 30分以内
                return 180  # 3分間隔
        
        # 連続空ポーリング
        if self.consecutive_empty_polls > 10:
            return 600  # 10分
        elif self.consecutive_empty_polls > 5:
            return 300  # 5分
        
        # 時間帯
        hour = now.hour
        if 0 <= hour < 6:  # 深夜
            return 900  # 15分
        elif 9 <= hour < 18:  # 業務時間
            return 180  # 3分
        else:
            return 300  # 5分
    
    def poll(self):
        interval = self.get_polling_interval()
        logger.info(f"Next poll in {interval} seconds")
        
        # レート制限カウント更新
        self.hourly_request_count += 1
        if (datetime.now() - self.hour_start).seconds > 3600:
            self.hourly_request_count = 1
            self.hour_start = datetime.now()
        
        # ポーリング実行
        tasks = self.find_tasks()
        
        if tasks:
            self.last_activity = datetime.now()
            self.consecutive_empty_polls = 0
        else:
            self.consecutive_empty_polls += 1
        
        time.sleep(interval)
```

## ポーリングの開始と終了

### 開始条件

```python
def should_start_polling():
    # 1. APIトークンの確認
    if not GITHUB_TOKEN:
        return False
    
    # 2. レート制限の確認
    rate_limit = check_rate_limit()
    if rate_limit.remaining < 100:
        logger.warning(f"Low rate limit: {rate_limit.remaining}")
        return False
    
    # 3. ネットワーク接続確認
    if not check_github_connectivity():
        return False
    
    return True
```

### 終了条件

```python
def should_stop_polling():
    # 1. 明示的な停止シグナル
    if stop_signal_received():
        return True
    
    # 2. レート制限枯渇
    if rate_limit.remaining < 10:
        logger.error("Rate limit exhausted")
        return True
    
    # 3. 連続エラー
    if consecutive_errors > 10:
        logger.error("Too many consecutive errors")
        return True
    
    # 4. 長期間アイドル（オプション）
    if idle_hours > 24:
        logger.info("Idle for 24 hours, stopping")
        return True
    
    return False
```

## バックオフ戦略

エラー時の段階的な間隔延長：

```python
class ExponentialBackoff:
    def __init__(self):
        self.base_delay = 60
        self.max_delay = 3600  # 1時間
        self.failure_count = 0
    
    def get_delay(self):
        delay = min(
            self.base_delay * (2 ** self.failure_count),
            self.max_delay
        )
        return delay + random.uniform(0, delay * 0.1)  # ジッター追加
    
    def record_success(self):
        self.failure_count = 0
    
    def record_failure(self):
        self.failure_count += 1
```

## 複数ワーカーの協調

```python
# ワーカー間でポーリングタイミングをずらす
def get_worker_offset(worker_name):
    offsets = {
        "CC01": 0,    # 0秒オフセット
        "CC02": 20,   # 20秒オフセット
        "CC03": 40,   # 40秒オフセット
    }
    return offsets.get(worker_name, 0)

# 使用例
time.sleep(get_worker_offset(WORKER_NAME))
start_polling()
```

## パフォーマンス指標

### 目標値
- **平均応答時間**: 3分以内（業務時間）
- **APIリクエスト数**: < 1,500/時間/ワーカー
- **成功率**: > 99%

### 監視項目
```python
metrics = {
    "polls_per_hour": 0,
    "tasks_found": 0,
    "average_response_time": 0,
    "api_errors": 0,
    "rate_limit_hits": 0
}
```

## 実装例（完全版）

```python
class OptimizedGitHubWorker:
    def __init__(self, worker_name):
        self.worker_name = worker_name
        self.poller = SmartPoller(worker_name)
        self.backoff = ExponentialBackoff()
        self.metrics = WorkerMetrics()
        
    def run(self):
        # 初期オフセット
        time.sleep(get_worker_offset(self.worker_name))
        
        while should_continue():
            try:
                # レート制限チェック
                if not self.check_rate_limit():
                    time.sleep(600)  # 10分待機
                    continue
                
                # ポーリング実行
                tasks = self.poll_for_tasks()
                
                if tasks:
                    self.process_tasks(tasks)
                    self.backoff.record_success()
                
                # 次回ポーリングまで待機
                interval = self.poller.get_polling_interval()
                self.metrics.record_poll(interval)
                time.sleep(interval)
                
            except RateLimitException:
                logger.warning("Rate limit hit")
                time.sleep(3600)  # 1時間待機
                
            except Exception as e:
                logger.error(f"Error: {e}")
                self.backoff.record_failure()
                time.sleep(self.backoff.get_delay())
```

## まとめ

この設計により：
- ✅ GitHub APIレート制限内で安全に動作
- ✅ 平均3分以内の応答性（業務時間）
- ✅ アダプティブな間隔調整
- ✅ エラー時の適切なバックオフ
- ✅ 複数ワーカーの効率的な協調

が実現されます。