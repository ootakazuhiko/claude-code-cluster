# 単一PC上での複数Claude Codeインスタンス対応設計

## アーキテクチャ概要

```
単一Ubuntu PC
├── Podman Container 1 (CC01 - Frontend)
│   ├── /workspace/frontend
│   └── Claude Code Instance 1
├── Podman Container 2 (CC02 - Backend)
│   ├── /workspace/backend
│   └── Claude Code Instance 2
├── Podman Container 3 (CC03 - Infrastructure)
│   ├── /workspace/infra
│   └── Claude Code Instance 3
└── Host System
    └── Central Webhook Router (Port 8888)
```

## 実装方法

### 1. ポート割り当て戦略

各インスタンスに異なるポートを割り当て：

```bash
# ~/.claude/config/hooks.conf の設定例

# CC01
WEBHOOK_PORT=8881
AGENT_NAME=CC01
CONTAINER_NAME=claude-cc01

# CC02
WEBHOOK_PORT=8882
AGENT_NAME=CC02
CONTAINER_NAME=claude-cc02

# CC03
WEBHOOK_PORT=8883
AGENT_NAME=CC03
CONTAINER_NAME=claude-cc03
```

### 2. 中央ルーター実装

ホストシステムで動作し、エージェントを識別して適切なコンテナにルーティング：

```python
# ~/.claude/hooks/central-router.py
from fastapi import FastAPI, Request, HTTPException
import httpx
import json

app = FastAPI()

# エージェントとポートのマッピング
AGENT_PORTS = {
    "CC01": 8881,
    "CC02": 8882,
    "CC03": 8883
}

@app.post("/webhook")
async def route_webhook(request: Request):
    """中央ルーターがWebhookを適切なエージェントに転送"""
    payload = await request.json()
    
    # ターゲットエージェントを決定
    target_agent = None
    
    # タスクタイプからエージェントを推定
    if payload.get("type") == "task":
        labels = payload.get("data", {}).get("labels", [])
        for label in labels:
            if label.startswith("cc") and label[2:4].isdigit():
                target_agent = label.upper()[:4]
                break
    
    # エージェント間メッセージの場合
    elif payload.get("type") == "agent_message":
        target_agent = payload.get("data", {}).get("to")
    
    if not target_agent or target_agent not in AGENT_PORTS:
        # ブロードキャスト（全エージェントに送信）
        results = {}
        for agent, port in AGENT_PORTS.items():
            try:
                async with httpx.AsyncClient() as client:
                    response = await client.post(
                        f"http://localhost:{port}/webhook",
                        json=payload,
                        timeout=5.0
                    )
                    results[agent] = response.json()
            except Exception as e:
                results[agent] = {"error": str(e)}
        return {"broadcast": True, "results": results}
    
    # 特定エージェントに転送
    port = AGENT_PORTS[target_agent]
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"http://localhost:{port}/webhook",
                json=payload,
                timeout=10.0
            )
            return response.json()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to reach {target_agent}: {str(e)}")

@app.get("/agents/status")
async def check_all_agents():
    """全エージェントの状態を確認"""
    status = {}
    for agent, port in AGENT_PORTS.items():
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(f"http://localhost:{port}/health", timeout=2.0)
                status[agent] = response.json()
        except:
            status[agent] = {"status": "offline"}
    return status
```

### 3. Podmanコンテナ設定

各Claude Codeインスタンス用のコンテナ設定：

```yaml
# podman-compose.yml
version: '3'

services:
  claude-cc01:
    image: ubuntu:24.04
    container_name: claude-cc01
    volumes:
      - ./workspaces/cc01:/workspace
      - ~/.claude/cc01:/root/.claude
    environment:
      - AGENT_NAME=CC01
      - WEBHOOK_PORT=8881
    ports:
      - "8881:8881"
    command: >
      bash -c "
        cd /workspace &&
        source /root/.claude/hooks/activate.sh &&
        claude
      "
  
  claude-cc02:
    image: ubuntu:24.04
    container_name: claude-cc02
    volumes:
      - ./workspaces/cc02:/workspace
      - ~/.claude/cc02:/root/.claude
    environment:
      - AGENT_NAME=CC02
      - WEBHOOK_PORT=8882
    ports:
      - "8882:8882"
    command: >
      bash -c "
        cd /workspace &&
        source /root/.claude/hooks/activate.sh &&
        claude
      "
  
  claude-cc03:
    image: ubuntu:24.04
    container_name: claude-cc03
    volumes:
      - ./workspaces/cc03:/workspace
      - ~/.claude/cc03:/root/.claude
    environment:
      - AGENT_NAME=CC03
      - WEBHOOK_PORT=8883
    ports:
      - "8883:8883"
    command: >
      bash -c "
        cd /workspace &&
        source /root/.claude/hooks/activate.sh &&
        claude
      "
```

### 4. 共有ファイルシステム利用

エージェント間の効率的な通信のため：

```bash
# 共有ディレクトリ構造
/opt/claude-cluster/
├── shared/
│   ├── task-queue/      # 共有タスクキュー
│   ├── messages/        # エージェント間メッセージ
│   └── artifacts/       # 共有成果物
├── workspaces/
│   ├── cc01/
│   ├── cc02/
│   └── cc03/
└── logs/
    ├── cc01/
    ├── cc02/
    └── cc03/
```

### 5. Hook設定の修正

ファイルベースの通信を活用：

```bash
# ~/.claude/hooks/on-agent-message.impl の修正
#!/bin/bash

MESSAGE_FILE="$1"
FROM_AGENT=$(jq -r .data.from "$MESSAGE_FILE")
TO_AGENT=$(jq -r .data.to "$MESSAGE_FILE")
SHARED_DIR="/opt/claude-cluster/shared/messages"

# 共有ディレクトリにメッセージを配置
MESSAGE_ID="$(date +%s)_${FROM_AGENT}_to_${TO_AGENT}"
cp "$MESSAGE_FILE" "$SHARED_DIR/$MESSAGE_ID.json"

# ファイルウォッチャーがピックアップ
echo "Message saved to shared directory: $MESSAGE_ID"
```

### 6. リソース管理

単一PC上でのリソース競合を避けるため：

```bash
# Podmanのリソース制限
podman run --cpus="2" --memory="4g" ...

# または systemd のリソース制御
# ~/.config/systemd/user/claude-cc01.service
[Service]
CPUQuota=200%
MemoryLimit=4G
```

## 移行手順

### 現在の複数PCから単一PCへの移行：

1. **中央ルーターのセットアップ**
   ```bash
   pip install fastapi httpx uvicorn
   python3 ~/.claude/hooks/central-router.py
   ```

2. **ワークスペースの準備**
   ```bash
   mkdir -p /opt/claude-cluster/{shared,workspaces,logs}
   mkdir -p /opt/claude-cluster/workspaces/{cc01,cc02,cc03}
   ```

3. **Hookシステムの調整**
   ```bash
   # 各エージェント用の設定を分離
   cp -r ~/.claude ~/.claude/cc01
   cp -r ~/.claude ~/.claude/cc02
   cp -r ~/.claude ~/.claude/cc03
   
   # ポート番号を変更
   sed -i 's/WEBHOOK_PORT=8888/WEBHOOK_PORT=8881/' ~/.claude/cc01/config/hooks.conf
   ```

4. **Podmanコンテナの起動**
   ```bash
   podman-compose up -d
   ```

## メリット

1. **リソース効率**: 単一PCで全エージェントを管理
2. **高速通信**: ローカルホスト内通信で低レイテンシ
3. **容易な管理**: 一箇所で全エージェントを制御
4. **柔軟なスケーリング**: エージェント数の動的調整

## 注意点

1. **ポート競合**: 各エージェントに固有のポートを割り当て
2. **リソース競合**: CPU/メモリの適切な配分
3. **ログ分離**: エージェントごとにログディレクトリを分離
4. **セキュリティ**: コンテナ間の適切な隔離

この設計により、現在の複数PC環境から将来の単一PC環境へスムーズに移行できます。