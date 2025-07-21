# Claude Code Cluster - 包括的インストールガイド

## 📋 目次

1. [はじめに](#はじめに)
2. [システム要件](#システム要件)
3. [インストール方法](#インストール方法)
4. [初期設定](#初期設定)
5. [動作確認](#動作確認)
6. [トラブルシューティング](#トラブルシューティング)
7. [次のステップ](#次のステップ)

## はじめに

このガイドでは、Claude Code Clusterのインストールから初期設定、動作確認までを包括的に説明します。

### 対象読者

- Windows + WSL2環境でClaude Codeを使用したい方
- 複数のClaude Codeエージェントを協調動作させたい方
- 自動化された開発環境を構築したい方

## システム要件

### ハードウェア要件

#### 最小構成
- **CPU**: 4コア以上
- **メモリ**: 16GB以上
- **ストレージ**: 100GB以上の空き容量
- **ネットワーク**: インターネット接続

#### 推奨構成
- **CPU**: 8コア以上
- **メモリ**: 32GB以上
- **ストレージ**: 500GB以上のSSD
- **ネットワーク**: 高速インターネット接続

### ソフトウェア要件

#### Windows側
- Windows 10 バージョン 2004以降 または Windows 11
- WSL2有効化済み
- Windows Terminal（推奨）

#### WSL2側
- Ubuntu 22.04 LTS または 24.04 LTS
- 基本的な開発ツール（git、curlなど）

## インストール方法

### 方法1: ワンコマンドインストール（推奨）

WSL2のUbuntu環境で以下のコマンドを実行するだけで、全ての環境が自動構築されます。

```bash
curl -sSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/wsl2/install-claude-cluster.sh | bash
```

### 方法2: 手動インストール

より詳細な制御が必要な場合は、手動でインストールできます。

#### 1. リポジトリのクローン

```bash
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster
```

#### 2. インストーラーの実行

```bash
chmod +x wsl2/install-claude-cluster.sh
./wsl2/install-claude-cluster.sh
```

### インストーラーが行う処理

1. **依存関係のインストール**
   - Python 3.12+
   - Node.js/npm
   - tmux、jq、その他ユーティリティ
   - FastAPI、uvicorn等のPythonパッケージ

2. **ユーザーとディレクトリの作成**
   - `claude-user`ユーザーの作成（セキュリティ向上）
   - `/home/claude-cluster/`ディレクトリ構造の作成

3. **エージェント環境の構築**
   - CC01（Frontend）、CC02（Backend）、CC03（Infrastructure）の設定
   - 各エージェント用のワークスペース作成
   - Hookシステムの設定

4. **管理ツールのインストール**
   - `claude-cluster`コマンドのインストール
   - Central Routerのセットアップ
   - systemdサービスの設定（オプション）

## 初期設定

### 1. Claude Codeの設定

インストール後、Claude Codeの認証情報を設定する必要があります。

```bash
# 各エージェントで認証設定
claude auth login
```

### 2. GitHub統合（オプション）

GitHub連携を行う場合：

```bash
# GitHubトークンの設定
export GITHUB_TOKEN="your-github-token"
echo "export GITHUB_TOKEN='your-github-token'" >> ~/.bashrc
```

### 3. エージェントの専門性カスタマイズ

各エージェントの設定ファイルで専門性を調整できます：

```bash
# CC01の設定
vim /home/claude-cluster/agents/cc01/.claude/config/hooks.conf

# CC02の設定
vim /home/claude-cluster/agents/cc02/.claude/config/hooks.conf

# CC03の設定
vim /home/claude-cluster/agents/cc03/.claude/config/hooks.conf
```

## 動作確認

### 1. クラスターの起動

```bash
# 全エージェントとルーターを起動
claude-cluster start
```

### 2. ステータス確認

```bash
# 全コンポーネントの状態を確認
claude-cluster status
```

期待される出力：
```
=== Claude Code Cluster Status ===

Central Router: Running
Agent CC01: Running
Agent CC02: Running
Agent CC03: Running

Agent Health:
CC01: healthy
CC02: healthy
CC03: healthy
```

### 3. テストタスクの実行

```bash
# 付属のテストスクリプトを実行
./wsl2/quick-test.sh
```

または手動でテスト：

```bash
# テストタスクを送信
cat > /tmp/test-task.json << EOF
{
    "type": "frontend_development",
    "priority": "normal",
    "description": "Create a simple React component"
}
EOF

claude-cluster task /tmp/test-task.json
```

### 4. ログの確認

```bash
# リアルタイムログ監視
claude-cluster logs

# 特定エージェントのログ
claude-cluster logs cc01
```

## トラブルシューティング

### よくある問題と解決方法

#### 1. エージェントが起動しない

**症状**: `claude-cluster status`でエージェントが"Stopped"と表示される

**解決方法**:
```bash
# tmuxセッションを確認
tmux ls

# 手動でエージェントを起動
claude-cluster start cc01

# ログを確認
tail -f /home/claude-cluster/agents/cc01/.claude/logs/*.log
```

#### 2. ポート競合

**症状**: "Address already in use"エラー

**解決方法**:
```bash
# 使用中のポートを確認
sudo netstat -tlnp | grep 888

# 設定ファイルでポート変更
vim /home/claude-cluster/agents/cc01/.claude/config/hooks.conf
# WEBHOOK_PORT=8891 に変更
```

#### 3. 権限エラー

**症状**: Permission deniedエラー

**解決方法**:
```bash
# ファイル所有権を確認
ls -la /home/claude-cluster/

# 必要に応じて修正
sudo chown -R claude-user:claude-group /home/claude-cluster/
```

#### 4. Claude Code認証エラー

**症状**: Claude Codeが認証を要求する

**解決方法**:
```bash
# claude-userとして認証
sudo -u claude-user claude auth login
```

### ログファイルの場所

問題解析に役立つログファイル：

```
/home/claude-cluster/shared/logs/
├── router.log              # Central Routerのログ
├── cc01-webhook.log        # CC01のWebhookログ
├── cc02-webhook.log        # CC02のWebhookログ
└── cc03-webhook.log        # CC03のWebhookログ

/home/claude-cluster/agents/cc01/.claude/logs/
└── *.log                   # CC01のClaude Codeログ
```

## Windows統合

### PowerShellモジュールの使用

Windows側からクラスターを制御できます：

```powershell
# モジュールのインポート
Import-Module \\wsl$\Ubuntu\home\claude-cluster\scripts\windows\ClaudeCluster.psm1

# 使用可能なコマンド
Start-ClaudeCluster         # クラスター起動
Stop-ClaudeCluster          # クラスター停止
Get-ClaudeClusterStatus     # ステータス確認
Send-ClaudeTask             # タスク送信
Watch-ClaudeLogs            # ログ監視
```

### Windows Terminalプロファイル

各エージェント用のプロファイルを追加：

1. Windows Terminalの設定を開く
2. `profiles`セクションに以下を追加：

```json
{
    "name": "Claude CC01 (Frontend)",
    "commandline": "wsl.exe -d Ubuntu -- tmux attach-session -t cc01",
    "icon": "🎨"
}
```

## 次のステップ

### 1. 実践的な使用

- [タスク作成ガイド](./TASK_CREATION_GUIDE.md)
- [エージェント間協調](./AGENT_COORDINATION.md)
- [GitHub統合ガイド](./GITHUB_INTEGRATION.md)

### 2. カスタマイズ

- [エージェント追加方法](./ADD_NEW_AGENT.md)
- [Hook開発ガイド](./HOOK_DEVELOPMENT.md)
- [パフォーマンスチューニング](./PERFORMANCE_TUNING.md)

### 3. 運用

- [バックアップとリストア](./BACKUP_RESTORE.md)
- [アップデート手順](./UPDATE_PROCEDURE.md)
- [監視設定](./MONITORING_SETUP.md)

## サポート

問題が解決しない場合：

1. [GitHub Issues](https://github.com/ootakazuhiko/claude-code-cluster/issues)で報告
2. [ディスカッション](https://github.com/ootakazuhiko/claude-code-cluster/discussions)で質問
3. ログファイルを添付して詳細を共有

---

Happy Coding with Claude Code Cluster! 🚀