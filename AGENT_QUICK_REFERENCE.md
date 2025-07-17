# 🚀 エージェント用クイックリファレンス

## ✅ 処理可能（これらのラベルがあれば処理）
```
claude-code-ready
claude-code-urgent
claude-code-backend
claude-code-frontend
claude-code-testing
claude-code-infrastructure
claude-code-database
claude-code-security
```

## 🚫 処理禁止（これらのラベルがあれば絶対処理しない）
```
discussion
design
on-hold
manual-only
blocked
wontfix
duplicate
invalid
```

## 👤 エージェント担当

### CC01 (フロントエンド)
- メイン: `claude-code-frontend`
- サブ: `claude-code-ready`, `claude-code-urgent`

### CC02 (バックエンド)
- メイン: `claude-code-backend`, `claude-code-database`
- サブ: `claude-code-security`

### CC03 (インフラ/テスト)
- メイン: `claude-code-infrastructure`, `claude-code-testing`
- サブ: `claude-code-ready`

## 🔄 処理フロー
1. ラベル確認 → 処理可能？ → 除外ラベルなし？ → 担当分野？
2. `claude-code-processing` 追加
3. 処理実行
4. 完了: `claude-code-completed` / 失敗: `claude-code-failed`
5. `claude-code-processing` 削除

## ⚠️ 重要
- ラベルなし = 処理しない
- 除外ラベル = 絶対処理しない
- 他エージェント処理中 = 触らない
- Issueクローズ = しない