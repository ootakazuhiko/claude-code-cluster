# エージェント活動監視ガイド

**作成日**: 2025年7月26日  
**更新日**: 2025年7月26日  
**重要度**: 高

## 概要

エージェント（CC01、CC02、CC03）の活動監視において、ラベルなしPRの見逃し問題が発生しました。
この文書は、同様の問題の再発防止と適切な監視手順を定めるものです。

## 問題の経緯

### 発生した問題
1. CC02が実際には活発に活動していたにも関わらず「活動なし」と誤判定
2. Day 8-12で5つのPRが作成されていたが、検出できなかった
3. 原因：PRにエージェントラベル（cc01、cc02、cc03）が付いていなかった

### 根本原因
- 監視スクリプトがラベルのみでフィルタリング
- エージェントがPR作成時にラベルを付けていない
- authorベースの確認が行われていなかった

## 改善された監視手順

### 1. 基本的な確認コマンド

```bash
# 方法1: Author指定で全PR確認（推奨）
gh pr list --author "ootakazuhiko" --state all --limit 30

# 方法2: 最近のPRを時系列で確認
gh pr list --state all --limit 50 --json number,title,author,createdAt,labels | grep -B2 -A2 "ootakazuhiko"

# 方法3: 特定期間のコミット確認
git log --oneline --since="2 days ago" --all --author="ootakazuhiko"
```

### 2. エージェント別の活動確認

```bash
# CC01の活動確認
echo "=== CC01 Activity ==="
gh pr list --author "ootakazuhiko" --state all --limit 30 | grep -i "cc01\|frontend\|v5[0-9]"

# CC02の活動確認
echo "=== CC02 Activity ==="
gh pr list --author "ootakazuhiko" --state all --limit 30 | grep -i "cc02\|backend\|api\|v6[0-9]\|v7[0-9]"

# CC03の活動確認
echo "=== CC03 Activity ==="
gh pr list --author "ootakazuhiko" --state all --limit 30 | grep -i "cc03\|infra\|deploy\|v6[0-9]"
```

### 3. 活動判定基準

#### アクティブと判定する条件
- 24時間以内にPRが作成されている
- 24時間以内にコミットがある
- 現在作業中のIssueにコメントがある

#### 注意が必要な状態
- 48時間以上PRなし
- 最新Issueから3日以上経過
- Draft PRが長期間放置

## エージェントへの指示改善

### PR作成時の必須事項
```bash
# エージェントがPR作成時に使用すべきコマンド
gh pr create \
  --title "feat: [エージェント名] 実装内容" \
  --label "エージェント名" \
  --body "Issue #XXX の実装"
```

### 例：
```bash
# CC01の場合
gh pr create --title "feat: CC01 Dashboard implementation" --label "cc01" --body "Implements Issue #600"

# CC02の場合  
gh pr create --title "feat: CC02 Product API v66" --label "cc02" --body "Day 8 implementation"

# CC03の場合
gh pr create --title "feat: CC03 PostgreSQL HA setup" --label "cc03" --body "Implements Issue #621"
```

## チェックリスト

### 日次確認
- [ ] 各エージェントのPR作成状況（author検索）
- [ ] 未マージPRの確認と処理
- [ ] 停止しているエージェントへの指示

### 週次確認
- [ ] PRのラベル付け状況
- [ ] 要件定義書との整合性
- [ ] エージェント間の進捗バランス

## 教訓と今後の対策

1. **多角的な確認**: ラベルだけでなく、author、タイトル、本文での検索を併用
2. **定期的な手動確認**: 自動スクリプトの結果を過信せず、手動でも確認
3. **エージェント教育**: PR作成時のラベル付けを指示に明記
4. **監視ツールの改善**: 複数の検索方法を組み合わせた堅牢なスクリプト

## 関連ドキュメント
- [CLAUDE.md](/CLAUDE.md) - 開発ワークフローとPR作成手順
- [scripts/management/](/scripts/management/) - 管理用スクリプト