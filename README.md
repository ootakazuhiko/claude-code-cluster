# Claude Code Cluster

分散型Claude Code実行環境 - 複数のPCで並行開発を自動化

## 🎯 概要

Claude Code Clusterは、複数のClaude Code エージェントを独立したPC上で動作させ、GitHubを中心とした協調開発を自動化するシステムです。

### 主な特徴

- **分散実行**: 最大10台のPCで並行処理
- **専門特化**: 各エージェントがbackend、frontend、testing等に特化
- **独立ワークスペース**: 各PCが完全に独立した開発環境を維持
- **自動調整**: Central Coordinatorがタスクを最適分散
- **GitHub統合**: Issues/PRベースの完全自動化

## 🏗️ システム構成

```
┌─────────────────┐     ┌──────────────────────────────────────┐
│   GitHub Repo   │────▶│          Central Coordinator         │
└─────────────────┘     └──────────────────┬───────────────────┘
                                           │
                        ┌──────────────────┼───────────────────┐
                        ▼                  ▼                   ▼
                ┌───────────────┐  ┌───────────────┐   ┌───────────────┐
                │  Claude PC-1  │  │  Claude PC-2  │   │  Claude PC-3  │
                │   Backend     │  │   Frontend    │   │   Testing     │
                │  Specialist   │  │  Specialist   │   │  Specialist   │
                └───────────────┘  └───────────────┘   └───────────────┘
                        │                  │                   │
                        ▼                  ▼                   ▼
                ┌───────────────┐  ┌───────────────┐   ┌───────────────┐
                │ Workspace-1   │  │ Workspace-2   │   │ Workspace-3   │
                │ /workspace/   │  │ /workspace/   │   │ /workspace/   │
                │   backend     │  │   frontend    │   │   testing     │
                └───────────────┘  └───────────────┘   └───────────────┘
```

## 📁 ドキュメント構成

### 📋 ドキュメント

- [システム要件](docs/requirements.md) - ハードウェア・ソフトウェア要件
- [インストールガイド](docs/installation.md) - 初期セットアップ手順
- [設定リファレンス](docs/configuration.md) - 設定ファイル詳細
- [運用ガイド](docs/operations.md) - 日常運用手順
- [トラブルシューティング](docs/troubleshooting.md) - 問題解決ガイド

### 🏗️ アーキテクチャ

- [全体設計](architecture/overview.md) - システム全体の設計思想
- [ネットワーク構成](architecture/network.md) - ネットワーク設計
- [データフロー](architecture/dataflow.md) - データの流れ
- [セキュリティ設計](architecture/security.md) - セキュリティ要件

### 💻 実装

- [Coordinator実装](implementation/coordinator.md) - 中央調整システム
- [Agent実装](implementation/agent.md) - 各PC上のエージェント
- [GitHub統合](implementation/github-integration.md) - GitHub連携
- [API仕様](implementation/api-spec.md) - REST API仕様

### 🚀 デプロイメント

- [初期デプロイ](deployment/initial-setup.md) - 初回構築手順
- [自動デプロイ](deployment/automation.md) - 自動化スクリプト
- [設定管理](deployment/config-management.md) - Ansible使用手順

### 📊 監視

- [監視システム](monitoring/overview.md) - 監視の全体像
- [メトリクス](monitoring/metrics.md) - 収集メトリクス
- [アラート](monitoring/alerts.md) - アラート設定

### 📝 サンプル

- [設定例](examples/configurations/) - 実際の設定ファイル例
- [タスク例](examples/tasks/) - タスク実行例
- [スクリプト例](examples/scripts/) - 運用スクリプト例

## 🚀 クイックスタート

1. **前提条件の確認**
   ```bash
   # 最低要件: 3台のPC（Coordinator + Agent × 2）
   # 推奨: 5台のPC（Coordinator + Agent × 4）
   ```

2. **Coordinatorのセットアップ**
   ```bash
   cd deployment/
   ./setup-coordinator.sh
   ```

3. **Agentのデプロイ**
   ```bash
   ./deploy-agents.sh --count 4
   ```

4. **動作確認**
   ```bash
   curl http://coordinator.local:8080/status
   ```

## 🔧 開発環境

Claude Code Clusterは以下の技術スタックで構築されています：

- **言語**: Python 3.11+, TypeScript
- **フレームワーク**: FastAPI, React
- **データベース**: PostgreSQL, Redis
- **コンテナ**: Docker, Docker Compose
- **監視**: Prometheus, Grafana
- **自動化**: Ansible, systemd

## 📈 スケーラビリティ

- **最小構成**: 2台（Coordinator + Agent × 1）
- **推奨構成**: 5台（Coordinator + Agent × 4）
- **最大構成**: 11台（Coordinator + Agent × 10）

## 🤝 コントリビューション

プロジェクトへの貢献を歓迎します：

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. Pull Requestを作成

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## 📞 サポート

- **Issues**: [GitHub Issues](https://github.com/your-org/claude-code-cluster/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/claude-code-cluster/discussions)
- **Email**: support@your-org.com

---

*Last updated: 2025-01-09*