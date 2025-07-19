# Claude Code Cluster 実装分析レポート

## 現状の問題点

### 1. エージェント間の通信問題
- **問題**: GitHubイシューによる通信が機能していない
- **原因**: 
  - エージェントが既存タスクに集中し、新規イシューを監視していない
  - 自動割り当てワークフローの不具合（全てCC03に割り当て）
  - ポーリング方式の非効率性

### 2. タスク管理の課題
- **問題**: エージェントが単一タスクに長時間固執
- **原因**:
  - タスク優先度の動的変更メカニズムがない
  - 中断・再開の仕組みが不十分
  - 進捗の可視性が低い

### 3. リソース管理
- **問題**: CC03のCPU使用率73%、CC02の90時間連続稼働
- **原因**:
  - 負荷分散の仕組みがない
  - 休憩やタスク切り替えのトリガーがない

## Hook-based実装による解決策

### 1. GitHub Webhooks Integration

```yaml
# .github/workflows/agent-webhook-handler.yml
name: Agent Task Distribution
on:
  issues:
    types: [opened, labeled, assigned]
  issue_comment:
    types: [created]
  pull_request:
    types: [opened, synchronize]

jobs:
  distribute-task:
    runs-on: ubuntu-latest
    steps:
      - name: Parse Issue/PR
        id: parse
        run: |
          # Extract agent labels and priority
          echo "agent=$(echo '${{ github.event.issue.labels.*.name }}' | grep -o 'cc[0-9]\+')" >> $GITHUB_OUTPUT
          
      - name: Notify Agent via Hook
        run: |
          # Send webhook to agent-specific endpoint
          curl -X POST https://agent-${{ steps.parse.outputs.agent }}.local/webhook \
            -H "Content-Type: application/json" \
            -d '{
              "type": "task",
              "issue_number": ${{ github.event.issue.number }},
              "priority": "high",
              "action": "analyze"
            }'
```

### 2. Local Agent Hooks

```bash
# ~/.claude/hooks/on-task-received.sh
#!/bin/bash
# Triggered when new task webhook is received

TASK_FILE="$1"
PRIORITY=$(jq -r .priority "$TASK_FILE")
CURRENT_TASK=$(claude status --current-task)

# High priority task interruption
if [[ "$PRIORITY" == "critical" ]]; then
    claude task pause "$CURRENT_TASK"
    claude task start "$(jq -r .issue_number "$TASK_FILE")"
fi

# Task queue management
claude task queue add "$TASK_FILE" --priority "$PRIORITY"
```

### 3. Progress Monitoring Hooks

```bash
# ~/.claude/hooks/on-progress-update.sh
#!/bin/bash
# Triggered periodically during task execution

METRICS_FILE="$1"
CPU_USAGE=$(jq -r .cpu_usage "$METRICS_FILE")
DURATION=$(jq -r .duration_hours "$METRICS_FILE")

# Resource management
if (( $(echo "$CPU_USAGE > 70" | bc -l) )); then
    claude config set --performance-mode "balanced"
fi

# Long-running task intervention
if (( $(echo "$DURATION > 24" | bc -l) )); then
    claude task checkpoint
    claude notify "Task running for $DURATION hours. Consider breaking down."
fi
```

### 4. Inter-Agent Communication Hooks

```bash
# ~/.claude/hooks/on-agent-message.sh
#!/bin/bash
# Handle messages from other agents

MESSAGE_FILE="$1"
FROM_AGENT=$(jq -r .from "$MESSAGE_FILE")
TYPE=$(jq -r .type "$MESSAGE_FILE")

case "$TYPE" in
    "help_request")
        # CC02 requests help with type annotations
        if [[ "$FROM_AGENT" == "CC02" ]]; then
            claude analyze --context "typescript-types" \
                --provide-suggestions "$MESSAGE_FILE"
        fi
        ;;
    "status_query")
        # Respond with current status
        claude status --format json | \
            curl -X POST "https://agent-$FROM_AGENT.local/webhook" \
            -H "Content-Type: application/json" \
            -d @-
        ;;
esac
```

## 実装提案

### Phase 1: 基本的なHook機能 (1週間)

1. **GitHub Webhook受信機能**
   ```python
   # agent/webhook_server.py
   from fastapi import FastAPI, Request
   from claude_agent import ClaudeAgent
   
   app = FastAPI()
   agent = ClaudeAgent()
   
   @app.post("/webhook")
   async def handle_webhook(request: Request):
       payload = await request.json()
       
       if payload["action"] == "opened":
           # New issue/PR created
           agent.queue_task({
               "type": "github_issue",
               "number": payload["issue"]["number"],
               "priority": extract_priority(payload["issue"]["labels"])
           })
       
       return {"status": "accepted"}
   ```

2. **ローカルHookスクリプト**
   - タスク受信時: `on-task-received`
   - 進捗更新時: `on-progress-update`
   - エラー発生時: `on-error`
   - 完了時: `on-task-complete`

### Phase 2: エージェント間通信 (2週間)

1. **メッセージングプロトコル**
   ```json
   {
     "version": "1.0",
     "from": "CC01",
     "to": "CC02",
     "timestamp": "2025-01-19T16:45:00Z",
     "type": "collaboration_request",
     "payload": {
       "task": "type_definition_sync",
       "context": {
         "pr_number": 222,
         "files": ["types/user.ts", "schemas/user.py"]
       }
     }
   }
   ```

2. **協調作業フレームワーク**
   - 共有ワークスペース
   - リアルタイム同期
   - コンフリクト解決

### Phase 3: インテリジェント管理 (3週間)

1. **動的優先度管理**
   - CI/CD失敗率に基づく自動優先度調整
   - デッドライン考慮
   - 依存関係解析

2. **リソース最適化**
   - CPU/メモリ使用率モニタリング
   - 自動パフォーマンス調整
   - タスク分割提案

## 移行計画

### Step 1: Hook基盤の構築
```bash
# Install hook system
curl -sSL https://github.com/ootakazuhiko/claude-code-cluster/install-hooks.sh | bash

# Configure agent
claude config set hooks.enabled true
claude config set hooks.dir ~/.claude/hooks
```

### Step 2: 既存ワークフローの移行
1. GitHub Actionsワークフローを更新
2. エージェントにhookスクリプトをデプロイ
3. 段階的にポーリングからイベント駆動へ移行

### Step 3: モニタリングと調整
- メトリクス収集
- パフォーマンス分析
- 継続的改善

## 期待される効果

1. **レスポンス時間の改善**
   - ポーリング遅延の解消
   - 即時タスク通知

2. **リソース効率**
   - CPU使用率の最適化
   - 無駄な処理の削減

3. **協調作業の向上**
   - エージェント間の直接通信
   - 並行作業の実現

4. **可視性の向上**
   - リアルタイムステータス
   - 進捗の透明性

## 結論

Hook-basedアプローチにより、現在の問題の大部分が解決可能です。特に：
- GitHubイシューへの即時反応
- エージェント間の効率的な通信
- リソースの最適利用
- タスクの動的管理

実装は段階的に進め、各フェーズで効果を測定しながら進めることを推奨します。