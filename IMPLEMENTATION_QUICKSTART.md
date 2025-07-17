# 🚀 GitHub Actions最小コスト実装 - クイックスタート

## 📋 概要

Dockerやサーバー不要！GitHub Actionsのみで動作する軽量ラベルベース処理システムです。

## ✅ 主な特徴

- **コスト最小**: 月額$0〜$5程度
- **インフラ不要**: サーバー、DB、Docker一切不要
- **簡単セットアップ**: 3つのYAMLファイルのみ
- **自動スケーリング**: GitHub管理で安定稼働

## 🏷️ ラベル体系

### 処理指示ラベル
- `claude-code-ready` - 汎用処理
- `claude-code-urgent` - 緊急処理
- `claude-code-backend` - バックエンド特化
- `claude-code-frontend` - フロントエンド特化
- `claude-code-testing` - テスト特化
- `claude-code-infrastructure` - インフラ特化

### ステータスラベル
- `claude-code-waiting` - ラベル待ち
- `claude-code-processing` - 処理中
- `claude-code-completed` - 完了
- `claude-code-failed` - 失敗

### 除外ラベル
- `discussion`, `design`, `on-hold`, `manual-only` など

## 🔧 セットアップ手順

### 1. ワークフローファイルを配置

```bash
# リポジトリのルートで実行
git checkout -b feature/github-actions-processing

# .github/workflows/ ディレクトリが存在することを確認
mkdir -p .github/workflows

# 3つのワークフローファイルが配置済み:
# - label-processor.yml (メイン処理)
# - daily-report.yml (日次レポート)
# - setup-labels.yml (ラベル作成)
```

### 2. コミット＆プッシュ

```bash
git add .github/workflows/
git commit -m "Add GitHub Actions label-based processing system"
git push origin feature/github-actions-processing
```

### 3. Pull Request作成

```bash
gh pr create --title "Add lightweight label-based processing with GitHub Actions" \
  --body "Implements label-based issue processing using only GitHub Actions. No servers or Docker required."
```

### 4. マージ後、ラベル作成

```bash
# mainブランチにマージ後
gh workflow run setup-labels.yml
```

## 📊 使い方

### Issue処理の開始

1. Issueに処理ラベルを付ける
```bash
gh issue edit <issue-number> --add-label "claude-code-ready"
```

2. 自動処理が開始される
- `claude-code-processing` ラベルが付く
- 処理完了後、結果ラベルとコメントが追加される

### 日次レポート

毎日午前9時（UTC）に自動生成、または手動実行：
```bash
gh workflow run daily-report.yml
```

## 💡 カスタマイズ例

### 処理ロジックの追加

`label-processor.yml` の `Process Based on Type` ステップを編集：

```yaml
- name: Process Based on Type
  id: process
  run: |
    case "${{ needs.evaluate-labels.outputs.processing_type }}" in
      backend)
        # カスタムバックエンド処理
        python scripts/backend_processor.py
        ;;
      frontend)
        # カスタムフロントエンド処理
        node scripts/frontend_processor.js
        ;;
    esac
```

### Slack通知の追加

```yaml
- name: Notify Slack
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: failure
    text: 'Issue processing failed: #${{ github.event.issue.number }}'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

## 🔍 動作確認

### Actions実行状況
```bash
# 最新の実行を確認
gh run list --workflow=label-processor.yml

# 実行詳細を確認
gh run view <run-id>
```

### テストIssue作成
```bash
gh issue create --title "Test: Backend API implementation" \
  --body "Test issue for label processing" \
  --label "claude-code-backend"
```

## 📈 コスト管理

### 使用量確認
GitHub Settings → Billing → Actions で確認

### コスト削減のヒント
1. **条件付き実行**: 特定の時間帯のみ処理
2. **キャッシュ活用**: 依存関係をキャッシュ
3. **並列度制御**: 同時実行数を制限

## 🚨 トラブルシューティング

### Issueが処理されない
1. ラベルが正しく付いているか確認
2. 除外ラベルが付いていないか確認
3. Actions タブでエラーを確認

### ワークフローが動作しない
1. ワークフローファイルがmainブランチにあるか確認
2. リポジトリのActions設定を確認
3. 必要な権限があるか確認

## 📚 関連ドキュメント

- [詳細設計書](GITHUB_ACTIONS_MINIMAL_DESIGN.md)
- [GitHub Actions公式ドキュメント](https://docs.github.com/actions)
- [Issue #27](https://github.com/ootakazuhiko/claude-code-cluster/issues/27) - 改善提案

---

**Status**: ✅ Ready to Deploy  
**Cost**: 💰 $0-5/month  
**Complexity**: ⭐ Simple  

質問や問題がある場合は、Issue #27 でディスカッションしてください。