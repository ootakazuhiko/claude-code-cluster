# Claude Code Hook System 簡易セットアップガイド

## 最小限の手順（サービス化なし）

### 1. インストール
```bash
# リポジトリをクローン
cd ~
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster

# インストーラーを実行
./hooks/install-hooks.sh
```

### 2. 必要最小限の設定
```bash
# エージェント名を設定（CC01, CC02, CC03のいずれか）
export AGENT_NAME=CC01
echo "export AGENT_NAME=$AGENT_NAME" >> ~/.bashrc
```

### 3. Webhookサーバーを起動（必須）
```bash
# Hookを有効化
source ~/.claude/hooks/activate.sh

# これでWebhookサーバーが起動します
# 確認：
ps aux | grep webhook-server
```

**以上で基本設定は完了です。**

---

## インストーラー実行後の表示について

`./hooks/install-hooks.sh` 実行後に表示される内容：

```
To activate hooks:
  source ~/.claude/hooks/activate.sh          # ← これは必須

To start webhook server:
  python3 ~/.claude/hooks/webhook-server.py    # ← activate.shで自動起動されるので不要

To install as systemd service:               # ← サービス化しない場合は以下3行とも不要
  sudo cp ~/.claude/config/claude-webhook.service /etc/systemd/system/
  sudo systemctl enable claude-webhook
  sudo systemctl start claude-webhook
```

## つまり必要なのは：

1. **インストール**: `./hooks/install-hooks.sh`
2. **有効化**: `source ~/.claude/hooks/activate.sh`

この2つだけです。

## 動作確認

```bash
# Webhookサーバーが起動しているか確認
curl http://localhost:8888/health

# 正常なら以下のような応答：
# {"status":"healthy","hooks_dir":"/home/username/.claude/hooks"}
```

## 注意事項

- **サービス化は任意**: 常時起動が必要ない場合はサービス化不要
- **activate.shの実行**: 新しいターミナルセッションごとに必要
- **自動起動**: `.bashrc`に追加すれば自動化可能

```bash
# 自動起動したい場合（任意）
echo "source ~/.claude/hooks/activate.sh" >> ~/.bashrc
```

## トラブルシューティング

### Webhookサーバーが起動しない場合
```bash
# 手動で起動
python3 ~/.claude/hooks/webhook-server.py

# エラーが出る場合は依存関係をインストール
pip install fastapi uvicorn
```

### ポート8888が使用中の場合
```bash
# 設定ファイルでポートを変更
vim ~/.claude/config/hooks.conf
# WEBHOOK_PORT=8889 に変更
```