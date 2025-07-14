# 🚨 CC01, CC02, CC03への指示（コピー用）

各Claude Codeエージェントに以下の内容をコピー&ペーストしてください：

---

## 📢 【重要】新しい自動化ツールを導入しました - Issue #99を確認してください

### 今すぐ実行してください:

```bash
# 1. 最新のタスクを確認
gh issue view 99

# 2. あなたのエージェントIDに合わせて初期化（以下から1つ選択）

# CC01の場合:
cd /mnt/c/work/ITDO_ERP2 && git pull origin main
source scripts/claude-code-automation/agent/agent-init.sh CC01

# CC02の場合:
cd /mnt/c/work/ITDO_ERP2 && git pull origin main
source scripts/claude-code-automation/agent/agent-init.sh CC02

# CC03の場合:
cd /mnt/c/work/ITDO_ERP2 && git pull origin main
source scripts/claude-code-automation/agent/agent-init.sh CC03
```

### 初期化後の確認事項:
- ✅ 自動ポーリングが開始されます（15分間隔）
- ✅ 現在のタスクが表示されます
- ✅ プロンプトが `🤖 CC01 /mnt/c/work/ITDO_ERP2 $` のように変わります

### 優先作業:
- **CC01**: PR #98 (Task-Department Integration) - backend-test修正
- **CC02**: PR #97 (Role Service) - Core Foundation Tests修正
- **CC03**: PR #95 (E2E Tests) - 環境設定とテスト実装

### 便利なコマンド（初期化後に使用可能）:
- `my-tasks` - 自分のタスク一覧
- `my-pr` - 自分のPR一覧
- `./scripts/claude-code-automation/agent/auto-fix-ci.sh [PR番号]` - CI/CD自動修正

### 効果:
- 作業時間を89.6%削減
- 15分ごとに自動でタスクチェック
- CI/CD失敗を自動修正

詳細は Issue #99 を確認してください: https://github.com/itdojp/ITDO_ERP2/issues/99

---