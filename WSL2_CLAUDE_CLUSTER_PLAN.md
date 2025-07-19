# WSL2 Claude Code Cluster 構築計画

## 概要

Windows + WSL2環境で、専用のUbuntuイメージ上に複数のClaude Codeエージェントを簡単に構築できるシステムを作成します。

## 目標

1. **ワンコマンドインストール**: 単一のスクリプトで全環境を構築
2. **完全自動化**: ユーザー入力を最小限に
3. **即座に利用可能**: インストール後すぐに3つのエージェントが稼働
4. **WSL2最適化**: Windows環境との統合を考慮

## システム構成

```
Windows Host
└── WSL2
    └── Ubuntu 24.04 (claude-cluster)
        ├── Claude Code Agent CC01 (Frontend)
        ├── Claude Code Agent CC02 (Backend)
        ├── Claude Code Agent CC03 (Infrastructure)
        ├── Central Router (Port 8888)
        └── Shared Resources
```

## 実装計画

### Phase 1: 基盤構築スクリプト

1. **WSL2 Ubuntu設定スクリプト** (`wsl2-setup.ps1`)
   - WSL2の有効化確認
   - Ubuntu 24.04のインストール
   - 必要なパッケージの事前インストール

2. **Claude Code環境構築スクリプト** (`setup-claude-cluster.sh`)
   - Claude Codeのインストール
   - 3つのワークスペース作成
   - Hook システムの自動設定

### Phase 2: エージェント管理システム

1. **エージェント起動スクリプト** (`start-agents.sh`)
   - 3つのエージェントを別々のtmuxセッションで起動
   - 自動的にポート割り当て
   - ヘルスチェック機能

2. **管理コマンド** (`claude-cluster`)
   - `claude-cluster start` - 全エージェント起動
   - `claude-cluster stop` - 全エージェント停止
   - `claude-cluster status` - 状態確認
   - `claude-cluster logs` - ログ表示

### Phase 3: Windows統合

1. **Windows Terminal プロファイル**
   - 各エージェント用のプロファイル自動作成
   - カラーテーマ設定

2. **PowerShellコマンド**
   - `Start-ClaudeCluster` - Windows側から起動
   - `Send-ClaudeTask` - タスク送信

## ディレクトリ構造

```
/home/claude-cluster/
├── agents/
│   ├── cc01/
│   │   ├── workspace/
│   │   └── .claude/
│   ├── cc02/
│   │   ├── workspace/
│   │   └── .claude/
│   └── cc03/
│       ├── workspace/
│       └── .claude/
├── shared/
│   ├── tasks/
│   ├── logs/
│   └── artifacts/
├── scripts/
│   ├── setup/
│   ├── management/
│   └── hooks/
└── config/
    ├── agent-config.yaml
    └── router-config.yaml
```

## 主要コンポーネント

### 1. マスターインストーラー (`install-claude-cluster.sh`)

```bash
#!/bin/bash
# 完全自動インストール
# - 依存関係のインストール
# - Claude Codeのセットアップ
# - エージェント環境の構築
# - Hookシステムの設定
# - 管理ツールのインストール
```

### 2. エージェント設定テンプレート

各エージェント用の事前設定済みテンプレート：
- Git設定
- Claude設定
- Hook設定
- 環境変数

### 3. 中央管理ダッシュボード

シンプルなWebUIでエージェントの状態を可視化

## タイムライン

1. **Week 1**: 基本インストーラーとエージェント起動システム
2. **Week 2**: Hook統合と通信システム
3. **Week 3**: Windows統合とテスト

## 成功基準

1. WSL2上で `curl -sSL https://github.com/.../install.sh | bash` 一発で環境構築
2. 3つのエージェントが自動的に起動し、相互通信可能
3. Windows側から簡単にタスク送信可能
4. ログとステータスの一元管理