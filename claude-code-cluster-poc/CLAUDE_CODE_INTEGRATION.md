# Claude Code クラスター統合ガイド

## 🎯 Claude Code vs Claude API の違い

### 従来の実装（Claude API）
```python
# 従来: Claude APIを直接呼び出し
client = anthropic.Anthropic(api_key=api_key)
response = client.messages.create(
    model="claude-3-sonnet-20240229",
    messages=[{"role": "user", "content": prompt}]
)
```

### 新しい実装（Claude Code）
```bash
# 新実装: Claude Code CLIを実行
claude-code --directory /workspace/repo \
           --prompt "Issue #123を解決してください" \
           --files src/
```

## 🏗️ アーキテクチャ変更

### 旧アーキテクチャ（Claude API）
```
GitHub Issue → Python Agent → Claude API → Code Generation → PR
```

### 新アーキテクチャ（Claude Code）
```
GitHub Issue → Task Manager → Agent PC → Claude Code CLI → PR
                                     ↓
                            Independent Workspace
                            + Full Development Environment
```

## 🖥️ Agent PC 構成

### 各PCの役割分担

#### 1. Backend Specialist PC
```bash
# インストール必要ツール
sudo apt update && sudo apt install -y \
    python3.11 python3.11-venv python3-pip \
    postgresql-client redis-tools \
    docker.io docker-compose \
    git curl wget

# Python開発環境
curl -LsSf https://astral.sh/uv/install.sh | sh
pip install poetry pytest black isort mypy

# Claude Code インストール
# （実際のインストール方法は公式ドキュメント参照）
# curl -fsSL https://claude.ai/install.sh | sh

# Agent daemon setup
mkdir -p /opt/claude-agent/{workspaces,config,logs}
```

#### 2. Frontend Specialist PC
```bash
# Node.js 環境
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 20
npm install -g yarn typescript @types/node

# Frontend tools
npm install -g create-react-app next-cli vite
npm install -g jest cypress playwright

# Build tools
sudo apt install -y build-essential
```

#### 3. Testing Specialist PC
```bash
# 多言語テスト環境
# Python testing
pip install pytest pytest-cov pytest-asyncio selenium

# JavaScript testing  
npm install -g jest @testing-library/react cypress playwright

# Browser automation
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo apt install google-chrome-stable firefox
```

#### 4. DevOps Specialist PC
```bash
# Container & orchestration
sudo apt install docker.io docker-compose kubectl
sudo usermod -aG docker $USER

# Infrastructure tools
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt install terraform ansible

# Cloud CLIs
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
```

## 🔧 Agent Daemon 実装

### Core Agent Class

```python
# /opt/claude-agent/agent.py
import asyncio
import subprocess
import json
import tempfile
from pathlib import Path
from typing import Dict, Any, Optional
import httpx
import git

class ClaudeCodeAgent:
    def __init__(self, config_path: str):
        self.config = self.load_config(config_path)
        self.agent_id = self.config['agent_id']
        self.specialties = self.config['specialties']
        self.coordinator_url = self.config['coordinator_url']
        self.workspace_root = Path(self.config['workspace_root'])
        self.max_concurrent = self.config.get('max_concurrent_tasks', 2)
        self.current_tasks = set()
        
    async def start(self):
        """Agent daemon開始"""
        print(f"Starting Claude Code Agent: {self.agent_id}")
        print(f"Specialties: {', '.join(self.specialties)}")
        
        # Coordinatorに登録
        await self.register_with_coordinator()
        
        # メインループ開始
        await asyncio.gather(
            self.heartbeat_loop(),
            self.task_polling_loop()
        )
    
    async def execute_task(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """Claude Codeを使用してタスクを実行"""
        task_id = task['id']
        
        try:
            print(f"Starting task {task_id}: {task['title']}")
            
            # 1. ワークスペース作成
            workspace = await self.create_workspace(task_id)
            
            # 2. リポジトリクローン
            repo_url = await self.get_repository_url(task['repository_name'])
            repo_path = workspace / "repository"
            await self.clone_repository(repo_url, repo_path)
            
            # 3. Claude Code context準備
            context = await self.prepare_claude_context(task, repo_path)
            
            # 4. Claude Code実行
            result = await self.run_claude_code(context, repo_path)
            
            if not result['success']:
                return {'success': False, 'error': f"Claude Code failed: {result['error']}"}
            
            # 5. 変更のレビューと検証
            changes = await self.review_changes(repo_path)
            
            # 6. テスト実行
            test_result = await self.run_tests(repo_path)
            
            # 7. PR作成（テスト成功時）
            if test_result['success']:
                pr_url = await self.create_pull_request(task, repo_path, changes)
                return {
                    'success': True,
                    'pr_url': pr_url,
                    'changes': changes,
                    'test_results': test_result
                }
            else:
                return {
                    'success': False,
                    'error': f"Tests failed: {test_result['error']}",
                    'test_results': test_result
                }
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
        
        finally:
            # ワークスペース cleanup
            await self.cleanup_workspace(workspace)
            self.current_tasks.discard(task_id)
    
    async def run_claude_code(self, context: str, repo_path: Path) -> Dict[str, Any]:
        """Claude Code CLIを実行"""
        
        # Claude Codeコマンド構築
        cmd = [
            'claude-code',
            '--directory', str(repo_path),
            '--non-interactive',  # 非対話モード
            '--output-format', 'json'  # 結果をJSON形式で出力
        ]
        
        # Issue内容をファイルとして準備
        context_file = repo_path / '.claude-context.md'
        context_file.write_text(context, encoding='utf-8')
        
        try:
            # Claude Code実行
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdin=asyncio.subprocess.PIPE,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                cwd=repo_path
            )
            
            # Context をstdinで渡す
            stdout, stderr = await process.communicate(input=context.encode('utf-8'))
            
            if process.returncode == 0:
                return {
                    'success': True,
                    'output': stdout.decode('utf-8'),
                    'changes': await self.parse_claude_output(stdout.decode('utf-8'))
                }
            else:
                return {
                    'success': False,
                    'error': stderr.decode('utf-8') if stderr else 'Unknown error'
                }
                
        except Exception as e:
            return {'success': False, 'error': str(e)}
        
        finally:
            # Context file cleanup
            if context_file.exists():
                context_file.unlink()
    
    async def prepare_claude_context(self, task: Dict[str, Any], repo_path: Path) -> str:
        """Claude Code用のコンテキストを準備"""
        
        # Repository情報を収集
        repo_info = await self.analyze_repository(repo_path)
        
        # 専門分野に応じたコンテキスト強化
        specialty_context = self.get_specialty_context(task, repo_info)
        
        context = f"""
# GitHub Issue Resolution

## Issue Information
- **Issue #{task['github_issue_id']}**: {task['title']}
- **Repository**: {task['repository_name']}
- **Specialty**: {task['specialty']}

## Issue Description
{task['description']}

## Repository Analysis
{repo_info['summary']}

## Current File Structure
{repo_info['file_structure']}

## Detected Technologies
{', '.join(repo_info['technologies'])}

## Requirements Analysis
{json.dumps(task['requirements'], indent=2)}

## Specialty-Specific Context
{specialty_context}

## Task Instructions
Please analyze this issue and implement the necessary changes:

1. Understand the current codebase structure
2. Implement the required functionality described in the issue
3. Follow existing code patterns and conventions
4. Add appropriate tests for the new functionality
5. Update documentation if necessary

Please make the necessary changes to resolve this issue completely.
"""
        return context
    
    def get_specialty_context(self, task: Dict[str, Any], repo_info: Dict[str, Any]) -> str:
        """専門分野に応じたコンテキストを生成"""
        
        if 'backend' in self.specialties:
            return f"""
### Backend Development Context
- Focus on server-side logic, APIs, and database operations
- Follow FastAPI/Django best practices
- Implement proper error handling and logging
- Consider database migrations if needed
- Ensure API documentation is updated
- Available tools: {', '.join(repo_info.get('backend_tools', []))}
"""
        
        elif 'frontend' in self.specialties:
            return f"""
### Frontend Development Context
- Focus on UI/UX implementation and user interactions
- Follow React/TypeScript best practices
- Ensure responsive design and accessibility
- Implement proper state management
- Add unit tests for components
- Available tools: {', '.join(repo_info.get('frontend_tools', []))}
"""
        
        elif 'testing' in self.specialties:
            return f"""
### Testing Specialist Context
- Focus on comprehensive test coverage
- Implement unit, integration, and e2e tests as appropriate
- Follow testing best practices for the detected framework
- Ensure test reliability and maintainability
- Add performance and security tests if relevant
- Available tools: {', '.join(repo_info.get('testing_tools', []))}
"""
        
        elif 'devops' in self.specialties:
            return f"""
### DevOps Specialist Context
- Focus on infrastructure, deployment, and CI/CD improvements
- Follow containerization and orchestration best practices
- Implement monitoring and logging solutions
- Ensure security and scalability considerations
- Update deployment documentation
- Available tools: {', '.join(repo_info.get('devops_tools', []))}
"""
        
        else:
            return "### General Development Context\n- Follow project conventions and best practices"
    
    async def analyze_repository(self, repo_path: Path) -> Dict[str, Any]:
        """リポジトリを分析して構造と技術スタックを把握"""
        
        analysis = {
            'summary': '',
            'file_structure': '',
            'technologies': [],
            'backend_tools': [],
            'frontend_tools': [],
            'testing_tools': [],
            'devops_tools': []
        }
        
        # ファイル構造を取得（重要なファイルのみ）
        important_files = []
        for pattern in ['*.py', '*.js', '*.ts', '*.jsx', '*.tsx', '*.json', '*.yml', '*.yaml', 'Dockerfile', 'docker-compose.*', '*.md']:
            important_files.extend(repo_path.glob(f"**/{pattern}"))
        
        # ファイル構造を文字列として構築（最初の50ファイル）
        structure_lines = []
        for file_path in sorted(important_files)[:50]:
            rel_path = file_path.relative_to(repo_path)
            structure_lines.append(str(rel_path))
        
        analysis['file_structure'] = '\n'.join(structure_lines)
        
        # 技術スタック検出
        if (repo_path / 'requirements.txt').exists() or (repo_path / 'pyproject.toml').exists():
            analysis['technologies'].append('Python')
            analysis['backend_tools'].extend(['Python', 'pip/uv'])
            
        if (repo_path / 'package.json').exists():
            analysis['technologies'].append('JavaScript/TypeScript')
            analysis['frontend_tools'].extend(['Node.js', 'npm/yarn'])
            
        if (repo_path / 'Dockerfile').exists():
            analysis['technologies'].append('Docker')
            analysis['devops_tools'].append('Docker')
            
        if any(repo_path.glob('**/*.test.py')) or any(repo_path.glob('**/*.test.js')):
            analysis['testing_tools'].extend(['Testing Framework'])
        
        # プロジェクト概要を生成
        analysis['summary'] = f"Repository with {len(important_files)} important files, using {', '.join(analysis['technologies'])}"
        
        return analysis
    
    async def run_tests(self, repo_path: Path) -> Dict[str, Any]:
        """専門分野に応じたテストを実行"""
        
        test_commands = []
        
        # Python tests
        if (repo_path / 'requirements.txt').exists() or (repo_path / 'pyproject.toml').exists():
            if any(repo_path.glob('**/test_*.py')):
                test_commands.append(['python', '-m', 'pytest', '-v'])
        
        # JavaScript/TypeScript tests
        if (repo_path / 'package.json').exists():
            package_json = json.loads((repo_path / 'package.json').read_text())
            if 'test' in package_json.get('scripts', {}):
                test_commands.append(['npm', 'test'])
        
        # テスト実行
        all_success = True
        test_outputs = []
        
        for cmd in test_commands:
            try:
                process = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=repo_path
                )
                
                stdout, stderr = await process.communicate()
                
                test_outputs.append({
                    'command': ' '.join(cmd),
                    'success': process.returncode == 0,
                    'output': stdout.decode('utf-8'),
                    'error': stderr.decode('utf-8') if stderr else None
                })
                
                if process.returncode != 0:
                    all_success = False
                    
            except Exception as e:
                test_outputs.append({
                    'command': ' '.join(cmd),
                    'success': False,
                    'error': str(e)
                })
                all_success = False
        
        return {
            'success': all_success,
            'tests': test_outputs,
            'error': None if all_success else 'Some tests failed'
        }
    
    async def create_pull_request(self, task: Dict[str, Any], repo_path: Path, changes: Dict[str, Any]) -> str:
        """変更をコミットしてPRを作成"""
        
        repo = git.Repo(repo_path)
        
        # ブランチ作成
        branch_name = f"claude-fix-issue-{task['github_issue_id']}"
        repo.git.checkout('-b', branch_name)
        
        # 変更をステージング
        repo.git.add('.')
        
        # コミット
        commit_message = f"""Fix issue #{task['github_issue_id']}: {task['title']}

{task['description'][:200]}...

Generated by Claude Code Agent ({self.agent_id})
Specialty: {', '.join(self.specialties)}
"""
        
        repo.index.commit(commit_message)
        
        # プッシュ
        origin = repo.remote('origin')
        origin.push(branch_name)
        
        # GitHub APIでPR作成
        pr_data = {
            'title': f"[Claude Code] Fix issue #{task['github_issue_id']}: {task['title']}",
            'body': f"""## Summary
This PR resolves issue #{task['github_issue_id']}.

{task['description']}

## Changes Made
{self.format_changes_summary(changes)}

## Agent Information
- **Agent ID**: {self.agent_id}
- **Specialties**: {', '.join(self.specialties)}
- **Generated by**: Claude Code Agent

## Testing
{self.format_test_summary(changes.get('test_results', {}))}

Closes #{task['github_issue_id']}
""",
            'head': branch_name,
            'base': 'main'
        }
        
        # GitHub API call to create PR
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://api.github.com/repos/{task['repository_name']}/pulls",
                headers={
                    'Authorization': f"token {self.config['github_token']}",
                    'Accept': 'application/vnd.github.v3+json'
                },
                json=pr_data
            )
            
            if response.status_code == 201:
                pr_info = response.json()
                return pr_info['html_url']
            else:
                raise Exception(f"Failed to create PR: {response.text}")
```

## 🔗 Coordinator統合

### Task Assignment API

```python
# coordinator/agent_manager.py
class AgentManager:
    async def assign_task(self, task_id: str, specialty: str) -> bool:
        """最適なAgentにタスクを割り当て"""
        
        # 専門分野に合致するAgentを検索
        suitable_agents = await self.find_suitable_agents(specialty)
        
        if not suitable_agents:
            logger.warning(f"No suitable agents for specialty: {specialty}")
            return False
        
        # 負荷の低いAgentを選択
        best_agent = min(suitable_agents, key=lambda a: a.current_tasks)
        
        # Agentにタスクを送信
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"http://{best_agent.hostname}:8000/tasks",
                json={'task_id': task_id},
                timeout=30.0
            )
            
            if response.status_code == 200:
                # Agent の負荷を更新
                best_agent.current_tasks += 1
                await self.update_agent_status(best_agent)
                return True
            else:
                logger.error(f"Failed to assign task to {best_agent.id}: {response.text}")
                return False
```

## 📊 設定例

### Agent設定ファイル

```yaml
# /opt/claude-agent/config/agent.yml
agent_id: "backend-specialist-001"
hostname: "192.168.1.11"
coordinator_url: "http://192.168.1.10:8080"

specialties:
  - backend
  - api
  - database
  - python

workspace_root: "/opt/claude-agent/workspaces"
max_concurrent_tasks: 2

github:
  token: "ghp_your_token_here"
  ssh_key: "/home/claude/.ssh/id_rsa"

claude_code:
  version: "latest"
  config_path: "/home/claude/.claude-config"

logging:
  level: "INFO"
  file: "/opt/claude-agent/logs/agent.log"
```

## 🚀 デプロイメント手順

### 1. Coordinator PC セットアップ

```bash
# PostgreSQL + Redis
docker-compose up -d postgres redis

# Coordinator API起動
cd coordinator/
python -m uvicorn main:app --host 0.0.0.0 --port 8080
```

### 2. Agent PC セットアップ

```bash
# 各Agent PCで実行
sudo mkdir -p /opt/claude-agent/{config,workspaces,logs}
sudo chown claude:claude /opt/claude-agent -R

# Agent daemon起動
cd /opt/claude-agent
python agent.py --config config/agent.yml
```

### 3. 動作確認

```bash
# ヘルスチェック
curl http://192.168.1.10:8080/health
curl http://192.168.1.11:8000/health  # Backend Agent
curl http://192.168.1.12:8000/health  # Frontend Agent

# テストタスク投入
curl -X POST http://192.168.1.10:8080/webhook/github \
  -H "Content-Type: application/json" \
  -d '{"action": "opened", "issue": {"number": 1, "title": "Test Issue", "body": "Test Description"}, "repository": {"full_name": "test/repo"}}'
```

---

この設計により、Claude Code CLIを効果的に分散実行できるクラスターシステムが構築できます。各PCが独立したワークスペースでClaude Codeを実行し、専門分野に応じた最適な開発環境で作業を行います。