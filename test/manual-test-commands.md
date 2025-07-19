# Hook System 手動テストコマンド

以下のコマンドを実行して動作確認してください：

## 1. Webhookサーバーの確認

```bash
# ヘルスチェック
curl http://localhost:8888/health

# プロセス確認
ps aux | grep webhook-server
```

## 2. 基本的なタスク送信

```bash
# テストタスクを送信
curl -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "task",
    "source": "manual-test",
    "data": {
      "message": "Manual test task",
      "priority": "normal",
      "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }
  }'
```

## 3. 高優先度タスクのテスト

```bash
# 緊急タスクを送信
curl -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "task",
    "source": "manual-test",
    "data": {
      "message": "URGENT: Critical task test",
      "priority": "critical",
      "issue_number": 999
    }
  }'
```

## 4. GitHubイベントのシミュレーション

```bash
# GitHub issueイベント
curl -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "github_issue",
    "source": "github",
    "data": {
      "issue_number": 123,
      "title": "Test issue from manual test",
      "labels": ["bug", "cc01-task"],
      "priority": "high"
    }
  }'
```

## 5. エージェント間通信のテスト

```bash
# CC02からCC01へのメッセージ
curl -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "agent_message",
    "source": "CC02",
    "data": {
      "from": "CC02",
      "to": "CC01",
      "type": "help_request",
      "context": {
        "pr_number": 222,
        "issue": "type_annotations"
      }
    }
  }'
```

## 6. ログの確認

```bash
# リアルタイムログ監視
tail -f ~/.claude/logs/*.log

# Webhookサーバーログ
tail -f ~/.claude/logs/webhook-server.log

# 特定のhookログ
tail -f ~/.claude/logs/on-task-received.log
```

## 7. タスクキューの確認

```bash
# タスクキューの内容を表示
cat ~/.claude/task_queue.json | jq .

# タスクキューの監視
watch -n 1 'jq . ~/.claude/task_queue.json'
```

## 8. システム状態の確認

```bash
# Hook設定の確認
cat ~/.claude/config/hooks.conf

# インストールされたhookの一覧
ls -la ~/.claude/hooks/*.sh

# 実行可能か確認
for hook in ~/.claude/hooks/*.sh; do
    echo "Checking: $hook"
    [ -x "$hook" ] && echo "  ✓ Executable" || echo "  ✗ Not executable"
done
```

## 期待される結果

1. **ヘルスチェック**: `{"status":"healthy","hooks_dir":"/root/.claude/hooks"}`
2. **Webhook応答**: `{"status":"success","hook":"on-task-received"}`
3. **タスクキュー**: 送信したタスクがJSONファイルに追加される
4. **ログファイル**: 各hookの実行ログが記録される

## トラブルシューティング

### Webhookサーバーが応答しない場合
```bash
# ポートが使用されているか確認
netstat -tlnp | grep 8888

# 手動でサーバーを起動
python3 ~/.claude/hooks/webhook-server.py
```

### ログが生成されない場合
```bash
# ログディレクトリの権限確認
ls -la ~/.claude/logs/

# ディレクトリが存在しない場合は作成
mkdir -p ~/.claude/logs
```