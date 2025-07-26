# Monitoring Tools for Claude Code Cluster

このディレクトリには、Claude Code Clusterの監視・管理ツールが含まれています。

## 📁 ディレクトリ構成

```
monitoring/
├── README.md                    # このファイル
├── AGENT_MONITORING_GUIDE.md    # エージェント監視ガイド
└── scripts/
    └── check-agent-activity-v2.sh  # エージェント活動確認スクリプト
```

## 🔍 エージェント活動監視

### 基本的な使い方

```bash
# エージェント活動の確認
./scripts/check-agent-activity-v2.sh

# 特定のauthorの全PR確認
gh pr list --author "ootakazuhiko" --state all --limit 30
```

### 監視のベストプラクティス

1. **多角的な確認**
   - ラベルだけでなく、author名でも検索
   - PR本文やタイトルでエージェント名を検索

2. **定期的な確認**
   - 日次：各エージェントのPR作成状況
   - 週次：要件定義書との整合性チェック

3. **問題の早期発見**
   - 24時間以上PRがない場合は要注意
   - 48時間以上活動がない場合は介入必要

## 📝 関連ドキュメント

- [AGENT_MONITORING_GUIDE.md](AGENT_MONITORING_GUIDE.md) - 詳細な監視手順
- [ITDO_ERP2プロジェクト](https://github.com/itdojp/ITDO_ERP2) - 監視対象プロジェクト

## 🐛 既知の問題と対策

### PRラベル欠落問題
- **問題**: エージェントがPR作成時にラベルを付けない
- **対策**: author検索を併用し、エージェントへの指示を改善

### 活動検出漏れ
- **問題**: ラベルベースの検索で活動を見逃す
- **対策**: 改善されたスクリプト（v2）を使用

## 🔧 今後の改善予定

1. Web UIダッシュボードの実装
2. 自動アラート機能
3. 活動統計レポート生成
4. エージェント間の進捗比較機能