# Claude Code エージェントシステム運用ガイド

## 日常運用

### 毎日の確認事項

#### 1. システム状態の確認
```bash
# エージェントの稼働状況
systemctl status claude-agent@*

# または手動起動の場合
ps aux | grep -E "(start-agent|claude-code)"

# 簡易ステータス確認
./monitor-agents.sh
```

#### 2. ログの確認
```bash
# エラーログの確認
grep -i error .agent/logs/*.log | tail -20

# 処理済みタスクの確認
grep "Task completed" .agent/logs/agent-loop.log | tail -10

# 現在処理中のタスク
cat .agent/state/active_issue_* 2>/dev/null
```

#### 3. GitHub Issues の状態
```bash
# 未処理の Issue
gh issue list --label "cc01,cc02,cc03" --state open

# 最近クローズされた Issue
gh issue list --label "cc01,cc02,cc03" --state closed --limit 10

# エージェント別の負荷確認
echo "CC01: $(gh issue list --label cc01 --state open | wc -l) open issues"
echo "CC02: $(gh issue list --label cc02 --state open | wc -l) open issues"
echo "CC03: $(gh issue list --label cc03 --state open | wc -l) open issues"
```

### タスクの作成と管理

#### タスク作成のベストプラクティス

```bash
# 良い例：明確で実行可能なタスク
gh issue create \
  --title "[CC01] Add loading spinner to user dashboard" \
  --label "cc01" \
  --body "## Task Description
Add a loading spinner component to the user dashboard while data is being fetched.

## Requirements
- Use the existing Spinner component from components/ui/Spinner.tsx
- Show spinner during API calls
- Add proper aria-label for accessibility

## Acceptance Criteria
- [ ] Spinner appears during data loading
- [ ] Spinner disappears when data is loaded
- [ ] No layout shift when spinner appears/disappears
- [ ] Passes accessibility tests"
```

#### 優先度の設定
```bash
# 高優先度タスク
gh issue create \
  --title "[CC02 URGENT] Fix authentication bug in login endpoint" \
  --label "cc02,priority-high,bug" \
  --body "Critical bug: Users cannot login due to token validation error"

# 通常優先度タスク
gh issue create \
  --title "[CC03] Update CI pipeline for faster builds" \
  --label "cc03,enhancement" \
  --body "Optimize CI pipeline to reduce build time"
```

### エージェントの制御

#### 個別エージェントの再起動
```bash
# 停止
./stop-agent.sh CC01

# 設定を再読み込みして起動
source .env
./start-agent.sh CC01 cc01
```

#### 緊急停止
```bash
# 全エージェントの即時停止
pkill -f "start-agent.sh"

# または systemd の場合
sudo systemctl stop claude-agent@*
```

#### 一時停止と再開
```bash
# 一時停止（タスク処理を停止、プロセスは維持）
touch .agent/state/pause

# 再開
rm -f .agent/state/pause
```

### パフォーマンスチューニング

#### 処理間隔の調整
```bash
# .env を編集
LOOP_DELAY=120  # 2分間隔に変更（デフォルト: 60秒）

# エージェントを再起動して適用
```

#### メモリ使用量の監視
```bash
# メモリ使用量の確認
ps aux | grep -E "(claude-code|start-agent)" | awk '{sum+=$6} END {print "Total RSS: " sum/1024 " MB"}'

# 長時間実行後のメモリリーク確認
cat > check-memory.sh << 'EOF'
#!/bin/bash
while true; do
  date
  ps aux | grep -E "start-agent.sh CC" | grep -v grep | awk '{print $2, $6/1024 " MB", $11, $12}'
  echo "---"
  sleep 300  # 5分ごと
done
EOF
```

### トラブルシューティング

#### エージェントが応答しない場合

1. **ログを確認**
```bash
tail -100 .agent/logs/claude-code-hook.log
tail -100 .agent/logs/agent-loop.log
```

2. **API 接続を確認**
```bash
# GitHub API
gh api user

# Claude API (curl でテスト)
curl https://api.anthropic.com/v1/models \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01"
```

3. **プロセスの状態確認**
```bash
# プロセスがゾンビ化していないか
ps aux | grep defunct

# CPU 使用率が異常に高くないか
top -p $(pgrep -f "claude-code" | tr '\n' ',' | sed 's/,$//')
```

#### タスクが失敗し続ける場合

1. **失敗したタスクの詳細確認**
```bash
# 最新のエラーログ
grep -A 10 -B 10 "error\|failed" .agent/logs/report-generator.log
```

2. **手動でタスクを実行してデバッグ**
```bash
# 環境変数を設定して手動実行
export AGENT_NAME=CC01
export ISSUE_LABEL=cc01
./scripts/agent/instruction-handler.sh
```

3. **Issue を手動で処理済みにする**
```bash
gh issue close <issue-number> --comment "Manually processed due to agent error"
```

### バックアップとリカバリ

#### 定期バックアップ
```bash
# バックアップスクリプト
cat > backup-agent-data.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# ログとステートをバックアップ
tar -czf "$BACKUP_DIR/agent-data.tar.gz" .agent/

# 設定ファイルをバックアップ
cp .env "$BACKUP_DIR/"
cp claude-code-config.yaml "$BACKUP_DIR/"

# 古いバックアップを削除（7日以上）
find backups/ -name "agent-data.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x backup-agent-data.sh
```

#### リカバリ手順
```bash
# バックアップからの復元
BACKUP_DATE="20240119_120000"
tar -xzf "backups/$BACKUP_DATE/agent-data.tar.gz"
cp "backups/$BACKUP_DATE/.env" .
cp "backups/$BACKUP_DATE/claude-code-config.yaml" .
```

### セキュリティ

#### API キーのローテーション
```bash
# 新しいキーに更新
sed -i 's/sk-ant-api03-old/sk-ant-api03-new/g' .env
sed -i 's/ghp_old/ghp_new/g' .env

# エージェントを再起動
sudo systemctl restart claude-agent@*
```

#### アクセスログの監査
```bash
# GitHub API の使用状況
gh api rate_limit

# 異常なアクティビティの確認
grep -i "unauthorized\|forbidden" .agent/logs/*.log
```

### レポートと分析

#### 日次レポートの生成
```bash
cat > generate-daily-report.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d)
REPORT_FILE="reports/daily-$DATE.md"
mkdir -p reports

cat > "$REPORT_FILE" << EOL
# Daily Agent Report - $DATE

## Summary
- Total tasks processed: $(grep -c "task_complete" .agent/logs/report-generator.log)
- Failed tasks: $(grep -c "task_failed" .agent/logs/report-generator.log)
- Active agents: $(ps aux | grep -c "start-agent.sh")

## Task Breakdown by Agent
### CC01 (Frontend)
$(gh issue list --label cc01 --state closed --search "closed:$DATE" | wc -l) tasks completed

### CC02 (Backend)  
$(gh issue list --label cc02 --state closed --search "closed:$DATE" | wc -l) tasks completed

### CC03 (Infrastructure)
$(gh issue list --label cc03 --state closed --search "closed:$DATE" | wc -l) tasks completed

## Errors and Warnings
$(grep -i "error\|warning" .agent/logs/*.log | grep "$DATE" | wc -l) total

## Recommendations
- Review any failed tasks
- Check agent performance metrics
- Plan tomorrow's priorities
EOL

echo "Report generated: $REPORT_FILE"
EOF

chmod +x generate-daily-report.sh
```

### 高度な運用

#### 負荷分散
```bash
# エージェントの負荷を確認して再配分
cat > rebalance-tasks.sh << 'EOF'
#!/bin/bash
CC01_COUNT=$(gh issue list --label cc01 --state open | wc -l)
CC02_COUNT=$(gh issue list --label cc02 --state open | wc -l)
CC03_COUNT=$(gh issue list --label cc03 --state open | wc -l)

echo "Current load: CC01=$CC01_COUNT, CC02=$CC02_COUNT, CC03=$CC03_COUNT"

# 負荷が偏っている場合の警告
if [ $CC01_COUNT -gt 20 ]; then
  echo "WARNING: CC01 is overloaded. Consider redistributing tasks."
fi
EOF
```

#### カスタムフック
```bash
# タスク完了時の通知
cat > .claude-code/hooks/on-task-complete.sh << 'EOF'
#!/bin/bash
# Slack notification example
if [ "$TASK_SUCCESS" = "true" ]; then
  curl -X POST $SLACK_WEBHOOK_URL \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"Task #$ISSUE_NUMBER completed successfully by $AGENT_NAME\"}"
fi
EOF
```

## ベストプラクティス

1. **定期的なログローテーション**: ログファイルが大きくなりすぎないよう管理
2. **エージェントの定期再起動**: メモリリークを防ぐため週1回程度
3. **Issue テンプレートの使用**: 一貫性のあるタスク記述
4. **監視ダッシュボードの活用**: 問題の早期発見
5. **バックアップの自動化**: cronで日次バックアップ

## 次のステップ

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - 詳細なトラブルシューティング
- [ADVANCED_CONFIG.md](./ADVANCED_CONFIG.md) - 高度な設定とカスタマイズ
- [MONITORING.md](./MONITORING.md) - 監視とアラートの設定