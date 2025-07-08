# Claude Code Cluster PoC - シミュレーター実行ガイド

## 🎯 概要

実際に5台のPCを用意できない場合のために、**単一PC上でクラスター環境をシミュレート**する方法を説明します。

## 🐳 Docker Composeによるシミュレーション環境

### 前提条件

- **ホストPC要件**:
  - CPU: 8コア以上
  - メモリ: 32GB以上
  - ストレージ: 100GB以上の空き
  - OS: Ubuntu 20.04+ または macOS（Docker Desktop）

- **必須ソフトウェア**:
  - Docker 24.0+
  - Docker Compose 2.0+
  - Git
  - Claude Code CLI（ホストPCにインストール済み）

### セットアップ手順

#### 1. リポジトリ準備

```bash
# リポジトリクローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc

# シミュレーター用ディレクトリ作成
mkdir -p simulator/{coordinator,agents,workspaces}
```

#### 2. Docker Compose設定

`simulator/docker-compose.yml`を作成:

```yaml
version: '3.8'

services:
  # Coordinator Services
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: coordinator_db
      POSTGRES_USER: coordinator
      POSTGRES_PASSWORD: coordinator_pass
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - cluster_network

  redis:
    image: redis:7-alpine
    networks:
      - cluster_network

  coordinator:
    build:
      context: ..
      dockerfile: simulator/Dockerfile.coordinator
    depends_on:
      - postgres
      - redis
    ports:
      - "8080:8080"
      - "8081:80"  # Webhook server
    environment:
      DATABASE_URL: postgresql://coordinator:coordinator_pass@postgres:5432/coordinator_db
      REDIS_URL: redis://redis:6379/0
      GITHUB_TOKEN: ${GITHUB_TOKEN}
    volumes:
      - ./coordinator/logs:/app/logs
    networks:
      - cluster_network

  # Agent Simulators (Claude Code CLIはホストで実行)
  backend-agent:
    build:
      context: ..
      dockerfile: simulator/Dockerfile.agent
    ports:
      - "8001:8000"
    environment:
      AGENT_ID: backend-specialist-001
      AGENT_SPECIALTIES: backend,api,database,python
      COORDINATOR_URL: http://coordinator:8080
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      CLAUDE_CODE_HOST_PATH: /var/run/claude-code.sock
    volumes:
      - ./workspaces/backend:/workspace
      - /var/run/claude-code.sock:/var/run/claude-code.sock
      - ./agents/backend/logs:/app/logs
    networks:
      - cluster_network

  frontend-agent:
    build:
      context: ..
      dockerfile: simulator/Dockerfile.agent
    ports:
      - "8002:8000"
    environment:
      AGENT_ID: frontend-specialist-001
      AGENT_SPECIALTIES: frontend,react,typescript,ui
      COORDINATOR_URL: http://coordinator:8080
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      CLAUDE_CODE_HOST_PATH: /var/run/claude-code.sock
    volumes:
      - ./workspaces/frontend:/workspace
      - /var/run/claude-code.sock:/var/run/claude-code.sock
      - ./agents/frontend/logs:/app/logs
    networks:
      - cluster_network

  testing-agent:
    build:
      context: ..
      dockerfile: simulator/Dockerfile.agent
    ports:
      - "8003:8000"
    environment:
      AGENT_ID: testing-specialist-001
      AGENT_SPECIALTIES: testing,qa,pytest,jest,e2e
      COORDINATOR_URL: http://coordinator:8080
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      CLAUDE_CODE_HOST_PATH: /var/run/claude-code.sock
    volumes:
      - ./workspaces/testing:/workspace
      - /var/run/claude-code.sock:/var/run/claude-code.sock
      - ./agents/testing/logs:/app/logs
    networks:
      - cluster_network

  devops-agent:
    build:
      context: ..
      dockerfile: simulator/Dockerfile.agent
    ports:
      - "8004:8000"
    environment:
      AGENT_ID: devops-specialist-001
      AGENT_SPECIALTIES: devops,docker,kubernetes,ci,infrastructure
      COORDINATOR_URL: http://coordinator:8080
      GITHUB_TOKEN: ${GITHUB_TOKEN}
      CLAUDE_CODE_HOST_PATH: /var/run/claude-code.sock
    volumes:
      - ./workspaces/devops:/workspace
      - /var/run/claude-code.sock:/var/run/claude-code.sock
      - ./agents/devops/logs:/app/logs
    networks:
      - cluster_network

networks:
  cluster_network:
    driver: bridge

volumes:
  postgres_data:
```

#### 3. Claude Code Bridge設定

ホストのClaude Code CLIをコンテナから利用するためのブリッジスクリプト:

`simulator/claude-code-bridge.sh`:

```bash
#!/bin/bash
# Claude Code Bridge - ホストのClaude Codeをコンテナから実行

SOCKET_PATH="/var/run/claude-code.sock"

# ソケットサーバー起動
socat UNIX-LISTEN:$SOCKET_PATH,fork EXEC:"claude-code-wrapper.sh" &

echo "Claude Code bridge started on $SOCKET_PATH"
wait
```

`simulator/claude-code-wrapper.sh`:

```bash
#!/bin/bash
# Claude Code実行ラッパー

# リクエストを読み込み
read -r REQUEST

# JSONからパラメータ抽出
WORKSPACE=$(echo "$REQUEST" | jq -r '.workspace')
CONTEXT=$(echo "$REQUEST" | jq -r '.context')

# 一時ファイルにコンテキスト保存
CONTEXT_FILE=$(mktemp)
echo "$CONTEXT" > "$CONTEXT_FILE"

# ホストでClaude Code実行
cd "$WORKSPACE"
claude-code --context-file "$CONTEXT_FILE" --non-interactive

# クリーンアップ
rm -f "$CONTEXT_FILE"
```

#### 4. 環境変数設定

`.env`ファイル作成:

```bash
# GitHub設定
GITHUB_TOKEN=ghp_your_github_token_here

# Claude Code設定（ホストで設定済みの前提）
CLAUDE_CODE_SOCKET=/var/run/claude-code.sock

# その他
LOG_LEVEL=INFO
```

#### 5. シミュレーター起動

```bash
# Claude Code Bridge起動（別ターミナル）
cd simulator
sudo ./claude-code-bridge.sh

# Docker Compose起動
docker-compose up -d

# ログ確認
docker-compose logs -f
```

## 🖥️ ローカル開発環境（VM使用）

### VirtualBoxによる仮想環境構築

5台のVMを使用してより現実的な環境を構築:

#### 1. VM構成

| VM名 | CPU | メモリ | ディスク | ネットワーク |
|------|-----|--------|----------|-------------|
| coordinator-vm | 2 | 4GB | 50GB | 192.168.56.10 |
| backend-vm | 2 | 8GB | 100GB | 192.168.56.11 |
| frontend-vm | 2 | 8GB | 100GB | 192.168.56.12 |
| testing-vm | 2 | 8GB | 100GB | 192.168.56.13 |
| devops-vm | 2 | 8GB | 100GB | 192.168.56.14 |

#### 2. 自動プロビジョニング

Vagrantfile:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # Coordinator VM
  config.vm.define "coordinator" do |coordinator|
    coordinator.vm.hostname = "coordinator"
    coordinator.vm.network "private_network", ip: "192.168.56.10"
    coordinator.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = 2
    end
    coordinator.vm.provision "shell", path: "provision/coordinator.sh"
  end

  # Backend Agent VM
  config.vm.define "backend" do |backend|
    backend.vm.hostname = "backend-agent"
    backend.vm.network "private_network", ip: "192.168.56.11"
    backend.vm.provider "virtualbox" do |vb|
      vb.memory = "8192"
      vb.cpus = 2
    end
    backend.vm.provision "shell", path: "provision/agent-backend.sh"
  end

  # 他のVMも同様に定義...
end
```

## 🧪 簡易テスト環境

### 単一プロセスでの動作確認

最小限の動作確認のための簡易実行:

`simulator/simple-test.py`:

```python
#!/usr/bin/env python3
"""
Claude Code Cluster簡易テスト
単一プロセスで基本動作を確認
"""

import asyncio
import tempfile
from pathlib import Path
from unittest.mock import Mock, patch

# プロジェクトのパスを追加
import sys
sys.path.append(str(Path(__file__).parent.parent))

from src.clients.claude_code_client import ClaudeCodeClient
from src.services.state_manager import StateManager
from src.clients.github_client import GitHubClient


class SimulatedClaudeCode:
    """Claude Code CLIのシミュレーター"""
    
    def __init__(self):
        self.workspaces = {}
    
    async def execute(self, context: str, workspace: str) -> dict:
        """Claude Code実行をシミュレート"""
        print(f"[Simulated Claude Code] Workspace: {workspace}")
        print(f"[Simulated Claude Code] Context preview: {context[:200]}...")
        
        # 簡単なファイル生成をシミュレート
        workspace_path = Path(workspace)
        
        if "backend" in context.lower() or "api" in context.lower():
            # Backend タスクのシミュレーション
            (workspace_path / "api.py").write_text("""
from fastapi import FastAPI

app = FastAPI()

@app.get("/hello")
def hello():
    return {"message": "Hello from simulated backend"}
""")
            return {"success": True, "files_created": ["api.py"]}
        
        elif "frontend" in context.lower() or "react" in context.lower():
            # Frontend タスクのシミュレーション
            (workspace_path / "App.tsx").write_text("""
import React from 'react';

export const App: React.FC = () => {
    return <div>Hello from simulated frontend</div>;
};
""")
            return {"success": True, "files_created": ["App.tsx"]}
        
        else:
            # 汎用タスク
            (workspace_path / "solution.py").write_text("""
# Simulated solution
def solve():
    return "Task completed"
""")
            return {"success": True, "files_created": ["solution.py"]}


async def test_basic_flow():
    """基本的な処理フローをテスト"""
    
    print("=== Claude Code Cluster 簡易テスト ===\n")
    
    # 1. 初期化
    print("1. 初期化中...")
    state_manager = StateManager()
    simulator = SimulatedClaudeCode()
    
    # 2. タスク作成
    print("\n2. テストタスク作成...")
    test_issue = {
        "number": 999,
        "title": "Add user authentication API",
        "body": "Implement JWT-based authentication for the backend API",
        "labels": ["backend", "api"]
    }
    
    task_id = f"test-task-{test_issue['number']}"
    task = {
        "task_id": task_id,
        "issue": test_issue,
        "status": "pending",
        "analysis": {
            "requirements": ["backend", "api", "authentication"],
            "specialty": "backend"
        }
    }
    
    # 3. 専門分野判定
    print(f"\n3. 専門分野判定: {task['analysis']['specialty']}")
    
    # 4. ワークスペース作成
    print("\n4. ワークスペース作成...")
    with tempfile.TemporaryDirectory() as tmpdir:
        workspace = Path(tmpdir) / task_id
        workspace.mkdir()
        
        # 5. Claude Code実行（シミュレート）
        print("\n5. Claude Code実行（シミュレート）...")
        context = f"""
Issue #{test_issue['number']}: {test_issue['title']}

{test_issue['body']}

Please implement the necessary changes.
"""
        
        result = await simulator.execute(context, str(workspace))
        
        # 6. 結果確認
        print(f"\n6. 実行結果:")
        print(f"   - 成功: {result['success']}")
        print(f"   - 作成ファイル: {result['files_created']}")
        
        # 作成されたファイルの内容確認
        print("\n7. 生成されたコード:")
        for filename in result['files_created']:
            file_path = workspace / filename
            if file_path.exists():
                print(f"\n--- {filename} ---")
                print(file_path.read_text()[:200])
                if len(file_path.read_text()) > 200:
                    print("...")
    
    print("\n=== テスト完了 ===")


async def test_multi_agent():
    """複数エージェントの動作をシミュレート"""
    
    print("\n=== マルチエージェント シミュレーション ===\n")
    
    agents = [
        {"id": "backend-001", "specialties": ["backend", "api", "database"]},
        {"id": "frontend-001", "specialties": ["frontend", "react", "ui"]},
        {"id": "testing-001", "specialties": ["testing", "qa", "pytest"]},
        {"id": "devops-001", "specialties": ["devops", "docker", "ci"]}
    ]
    
    tasks = [
        {
            "id": "task-001",
            "title": "Create REST API endpoint",
            "requirements": ["backend", "api"],
            "best_agent": "backend-001"
        },
        {
            "id": "task-002", 
            "title": "Build React dashboard",
            "requirements": ["frontend", "react"],
            "best_agent": "frontend-001"
        },
        {
            "id": "task-003",
            "title": "Add unit tests",
            "requirements": ["testing", "pytest"],
            "best_agent": "testing-001"
        }
    ]
    
    print("エージェント一覧:")
    for agent in agents:
        print(f"  - {agent['id']}: {', '.join(agent['specialties'])}")
    
    print("\nタスク割り当て:")
    for task in tasks:
        print(f"  - {task['id']} ({task['title']}) → {task['best_agent']}")
    
    print("\n処理シミュレーション:")
    simulator = SimulatedClaudeCode()
    
    for task in tasks:
        print(f"\n[{task['best_agent']}] Processing {task['id']}...")
        with tempfile.TemporaryDirectory() as tmpdir:
            result = await simulator.execute(
                f"Task: {task['title']}", 
                tmpdir
            )
            print(f"  Result: {result}")


if __name__ == "__main__":
    # 基本フローテスト
    asyncio.run(test_basic_flow())
    
    # マルチエージェントテスト
    asyncio.run(test_multi_agent())
```

### テスト実行

```bash
# 簡易テスト実行
cd simulator
python3 simple-test.py

# 出力例:
# === Claude Code Cluster 簡易テスト ===
# 
# 1. 初期化中...
# 2. テストタスク作成...
# 3. 専門分野判定: backend
# 4. ワークスペース作成...
# 5. Claude Code実行（シミュレート）...
# 6. 実行結果:
#    - 成功: True
#    - 作成ファイル: ['api.py']
# ...
```

## 📊 パフォーマンステスト

### リソース使用量の目安

| 構成 | CPU使用率 | メモリ使用量 | ディスク |
|------|-----------|-------------|----------|
| Docker Compose (全サービス) | 40-60% | 16-20GB | 10GB |
| VirtualBox (5VM) | 60-80% | 28-32GB | 250GB |
| 簡易テスト | 5-10% | 1-2GB | 100MB |

### 負荷テストシナリオ

```bash
# 並行タスク投入テスト
for i in {1..10}; do
  curl -X POST http://localhost:8080/webhook/github \
    -H "Content-Type: application/json" \
    -d "{\"action\": \"opened\", \"issue\": {\"number\": $i, \"title\": \"Test Issue $i\", \"body\": \"Test description\"}}" &
done

# 結果確認
curl http://localhost:8080/api/tasks | jq '.tasks | length'
```

## 🔍 デバッグとモニタリング

### ログ集約

```bash
# 全コンテナのログを集約表示
docker-compose logs -f | grep -E "(ERROR|WARNING|Task|Agent)"

# 特定エージェントのログ
docker-compose logs -f backend-agent

# ログファイル監視
tail -f simulator/agents/*/logs/*.log
```

### メトリクス確認

```bash
# コンテナリソース使用状況
docker stats

# ネットワーク接続状況
docker network inspect claude-code-cluster-poc_cluster_network
```

## ⚡ クイックスタート

最速でシミュレーション環境を試す:

```bash
# 1. クローン
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster/claude-code-cluster-poc

# 2. 簡易テスト実行
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python simulator/simple-test.py

# 3. 結果確認
# シミュレートされたClaude Code実行結果が表示される
```

---

**注意**: シミュレーション環境は実際のClaude Code CLIの動作を完全に再現するものではありません。実際の動作確認には、適切にセットアップされた環境でのClaude Code CLIの使用が必要です。