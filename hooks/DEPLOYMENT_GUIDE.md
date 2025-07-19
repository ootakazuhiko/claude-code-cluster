# Claude Code Hook System 導入ガイド

## 前提条件
- Claude Codeが `/home/work/ITDO_ERP2` で動作中
- 各エージェント（CC01, CC02, CC03）のUbuntuインスタンスへのアクセス

## 導入手順

### 1. Hook システムのインストール

各エージェントのUbuntuインスタンスで以下を実行：

```bash
# claude-code-clusterリポジトリをクローン（ITDO_ERP2とは別の場所）
cd ~
git clone https://github.com/ootakazuhiko/claude-code-cluster.git

# インストーラーを実行
cd claude-code-cluster
./hooks/install-hooks.sh

# 環境変数を設定（エージェントごとに変更）
export AGENT_NAME=CC01  # CC01, CC02, CC03のいずれか
echo "export AGENT_NAME=$AGENT_NAME" >> ~/.bashrc
```

### 2. Claude Code設定の更新

**重要**: Claude Codeの再起動は不要です。Hookは外部プロセスとして動作します。

```bash
# Hook設定ファイルを編集
vim ~/.claude/config/hooks.conf
```

以下を設定：
```bash
HOOKS_ENABLED=true
WEBHOOK_PORT=8888
WEBHOOK_HOST=127.0.0.1
AGENT_NAME=CC01  # 各エージェントに応じて設定
LOG_LEVEL=INFO
CLAUDE_WORK_DIR=/home/work/ITDO_ERP2  # Claude Codeの作業ディレクトリ
```

### 3. Webhook サーバーの起動

```bash
# Hookシステムを有効化
source ~/.claude/hooks/activate.sh

# Webhookサーバーをバックグラウンドで起動
nohup python3 ~/.claude/hooks/webhook-server.py > ~/.claude/logs/webhook-server.log 2>&1 &

# 起動確認
curl http://localhost:8888/health
```

### 4. GitHub Integration用の設定

ITDO_ERP2リポジトリの `.github/workflows/` に以下を追加：

```yaml
# .github/workflows/agent-notification.yml
name: Notify Agents via Webhook
on:
  issues:
    types: [opened, labeled]
  pull_request:
    types: [opened, synchronize]

jobs:
  notify-agents:
    runs-on: ubuntu-latest
    steps:
      - name: Determine Target Agent
        id: agent
        run: |
          if [[ "${{ contains(github.event.issue.labels.*.name, 'cc01-task') }}" == "true" ]]; then
            echo "target=CC01" >> $GITHUB_OUTPUT
          elif [[ "${{ contains(github.event.issue.labels.*.name, 'cc02-task') }}" == "true" ]]; then
            echo "target=CC02" >> $GITHUB_OUTPUT
          elif [[ "${{ contains(github.event.issue.labels.*.name, 'cc03-task') }}" == "true" ]]; then
            echo "target=CC03" >> $GITHUB_OUTPUT
          fi
      
      - name: Send Webhook
        if: steps.agent.outputs.target != ''
        run: |
          # ローカルネットワーク内でのwebhook送信
          # 実際のエージェントのIPアドレスに置き換える
          curl -X POST http://${{ steps.agent.outputs.target }}-host:8888/webhook \
            -H "Content-Type: application/json" \
            -d '{
              "type": "github_issue",
              "source": "github",
              "data": {
                "issue_number": ${{ github.event.issue.number }},
                "title": "${{ github.event.issue.title }}",
                "labels": ${{ toJson(github.event.issue.labels.*.name) }}
              }
            }'
```

### 5. Claude Code との連携

Hookシステムは Claude Code の動作に直接介入せず、以下の方法で連携します：

1. **タスクキューファイル経由**
   ```bash
   # Hookがタスクを ~/.claude/task_queue.json に保存
   # Claude Codeが定期的にこのファイルをチェック
   ```

2. **通知システム経由**
   ```bash
   # 高優先度タスクの場合、システム通知を送信
   notify-send "Claude Code" "New high priority task received"
   ```

3. **ファイルウォッチャー経由**
   ```bash
   # Claude Codeの作業ディレクトリに指示ファイルを作成
   echo "Check issue #123" > /home/work/ITDO_ERP2/.claude-tasks/new-task.txt
   ```

## Claude Code 再起動について

**再起動は不要です**。理由：

1. **独立したプロセス**: Hookシステムは別プロセスとして動作
2. **ファイルベース通信**: Claude Codeとの連携はファイル経由
3. **非侵襲的**: 既存のClaude Code動作を妨げない

ただし、以下の場合は Claude Code の再起動を検討：

- 長時間稼働による性能低下（CC02の90時間稼働など）
- メモリリークの疑い
- 新しい設定の反映が必要な場合

### 安全な再起動手順（必要な場合のみ）

```bash
# 1. 現在の作業を保存
cd /home/work/ITDO_ERP2
git stash save "WIP: Before Claude restart $(date)"

# 2. Claude Codeを終了
# Ctrl+C または該当プロセスをkill

# 3. Hookシステムが起動していることを確認
ps aux | grep webhook-server

# 4. Claude Codeを再起動
cd /home/work/ITDO_ERP2
claude  # または通常の起動コマンド
```

## 動作確認

### 1. Webhook受信テスト

```bash
# テストwebhookを送信
curl -X POST http://localhost:8888/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "task",
    "source": "test",
    "data": {
      "message": "Test task",
      "priority": "low"
    }
  }'
```

### 2. タスクキューの確認

```bash
# タスクが正しくキューに追加されたか確認
cat ~/.claude/task_queue.json | jq .
```

### 3. ログの確認

```bash
# Hookシステムのログ
tail -f ~/.claude/logs/*.log

# Webhookサーバーのログ
tail -f ~/.claude/logs/webhook-server.log
```

## トラブルシューティング

### Webhookが受信されない
1. ファイアウォール設定を確認
2. ポート8888が開いているか確認
3. webhook-server.pyが起動しているか確認

### Claude Codeがタスクを認識しない
1. task_queue.jsonの権限を確認
2. Claude Codeの作業ディレクトリを確認
3. 通知設定を確認

### 高リソース使用時の対処
1. Hookの `on-resource-limit` が自動的に対処
2. 必要に応じて手動で優先度調整
3. 極端な場合のみClaude Code再起動

## 推奨事項

1. **段階的導入**: まず1エージェントでテスト
2. **監視強化**: 初期は頻繁にログ確認
3. **バックアップ**: 既存の作業を定期的に保存
4. **通信テスト**: エージェント間の疎通確認