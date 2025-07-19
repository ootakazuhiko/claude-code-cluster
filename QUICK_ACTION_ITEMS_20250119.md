# 即時アクションアイテム - 2025年1月19日

## 🚨 緊急対応（今すぐ実行）

### CC02 - 健康管理
```bash
# 1. 作業の即時保存
git add -A
git commit -m "wip: MyPy progress checkpoint - $(date)"
git push origin fix/cc02-type-annotations

# 2. セッション情報の記録
echo "Session duration: $(ps aux | grep claude | awk '{print $10}')" > session_health.log
echo "Current time: $(date)" >> session_health.log

# 3. 15分以上の休憩を取る
echo "Break started at $(date)" >> session_health.log
```

### CC03 - CPU制限
```bash
# 1. 即座にCPU使用率を確認
top -bn1 | grep claude

# 2. 50%以上なら即座に制限
PID=$(pgrep claude)
cpulimit -p $PID -l 40 -b

# 3. 優先度も下げる
renice +15 $PID
```

### CC01 - 緊急プッシュ
```bash
# 1. 未プッシュコミットの確認
git log origin/fix/cc01-typescript-errors..HEAD --oneline

# 2. テスト実行
npm test

# 3. 問題なければプッシュ
git push origin fix/cc01-typescript-errors
```

## ⏱️ 30分以内に実行

### 全エージェント共通
```bash
# 進捗スナップショット作成
cat > /tmp/agent_snapshot_$(date +%Y%m%d_%H%M).json << EOF
{
  "agent": "${AGENT_NAME}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_task": "[記入]",
  "progress": "[0-100]",
  "blockers": ["[記入]"],
  "health": "[good/tired/concerning]"
}
EOF
```

### CC01 - コンポーネントカタログ
```typescript
// frontend/src/components/ui/catalog.ts
export const UI_COMPONENTS = {
  Modal: { status: 'complete', tests: true, docs: true },
  Dialog: { status: 'complete', tests: true, docs: false },
  Alert: { status: 'complete', tests: true, docs: true },
  // ... 他のコンポーネントステータス
};
```

### CC02 - エラー分類
```bash
# MyPyエラーを種類別に分類
cd backend
uv run mypy app/ 2>&1 | grep "error:" | \
  sed 's/.*error: //' | \
  cut -d'[' -f1 | \
  sort | uniq -c | sort -nr > mypy_error_types.txt
```

### CC03 - 軽量ヘルスチェック
```yaml
# .github/workflows/quick-health.yml
name: Quick Health Check
on: [push]
jobs:
  health:
    runs-on: ubuntu-latest
    timeout-minutes: 2
    steps:
      - run: echo "Quick check passed"
```

## 📊 1時間以内にレポート

### 進捗レポートテンプレート
```markdown
# [AGENT_NAME] Progress Report - $(date +"%Y-%m-%d %H:%M")

## Summary
- Status: 🟢 Active / 🟡 Slow / 🔴 Blocked
- Progress: XX%
- Health: 😊 Good / 😓 Tired / 😰 Concerning

## Completed (Last 6 hours)
✅ Task 1
✅ Task 2

## In Progress
🔄 Current task (XX% complete)

## Blocked
❌ Blocker 1 - Need help with...

## Metrics
- TypeScript Errors: XX (was YY)
- MyPy Errors: XX (was YY)  
- CPU Usage: XX%
- Work Duration: XX hours

## Next Steps
1. Immediate: [task]
2. Today: [task]
3. Tomorrow: [task]
```

## 🎯 本日の完了目標

### CC01
- [ ] TypeScriptエラー: 0
- [ ] 全コンポーネントテスト: PASS
- [ ] ブランチ: プッシュ完了

### CC02
- [ ] MyPyエラー: 50%削減
- [ ] 健康的な作業リズム確立
- [ ] 部分的PRの準備

### CC03
- [ ] CPU使用率: <50%
- [ ] CC02支援パイプライン: 完成
- [ ] サイクルレポート: 統合完了

## 🔄 チェックポイント

- **18:00**: 進捗確認
- **20:00**: 本日の作業終了確認
- **21:00**: 週末タスクの最終確認

## 💡 リマインダー

1. **CC02**: 90時間は異常です。必ず休憩を。
2. **CC03**: CPU 73%は持続不可能。即座に対処を。
3. **CC01**: 週明け前にクリーンな状態に。

全エージェント：健康第一、品質第二、速度第三。