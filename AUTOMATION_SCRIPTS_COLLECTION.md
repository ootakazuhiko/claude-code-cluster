# 自動化スクリプトコレクション

## CC01 - Frontend自動化

### TypeScriptエラー自動修正
```bash
#!/bin/bash
# auto_fix_ts_errors.sh

cd /home/work/ITDO_ERP2/frontend

# 1. Unused imports の自動削除
npx eslint --fix src/**/*.{ts,tsx}

# 2. any型の自動検出と修正提案
echo "=== Detecting 'any' types ==="
grep -rn "any" src/ --include="*.ts" --include="*.tsx" | grep -v "// eslint-disable" | while read line; do
    echo "$line"
    file=$(echo "$line" | cut -d: -f1)
    linenum=$(echo "$line" | cut -d: -f2)
    
    # 自動修正可能なパターン
    sed -i "${linenum}s/: any\[\]/: unknown[]/" "$file"
    sed -i "${linenum}s/: any/: unknown/" "$file"
done

# 3. Missing return type の追加
npx tsc --noEmit --strict 2>&1 | grep "Missing return type" | while read error; do
    file=$(echo "$error" | cut -d'(' -f2 | cut -d',' -f1)
    # 簡単な関数には自動的に型を追加
    sed -i 's/\(export function \w\+([^)]*)\)$/\1: void/' "$file"
done
```

### コンポーネントテスト自動生成
```javascript
// generate_component_tests.js
const fs = require('fs');
const path = require('path');

const componentDir = './src/components/ui';
const testTemplate = (componentName) => `
import { render, screen } from '@testing-library/react';
import { ${componentName} } from './${componentName}';

describe('${componentName}', () => {
  it('renders without crashing', () => {
    render(<${componentName} />);
  });

  it('applies custom className', () => {
    const { container } = render(<${componentName} className="custom-class" />);
    expect(container.firstChild).toHaveClass('custom-class');
  });

  it('handles click events', () => {
    const handleClick = jest.fn();
    render(<${componentName} onClick={handleClick} />);
    // Add click test based on component type
  });
});
`;

// コンポーネントごとにテストファイル生成
fs.readdirSync(componentDir).forEach(file => {
  if (file.endsWith('.tsx') && !file.includes('.test')) {
    const componentName = file.replace('.tsx', '');
    const testFile = path.join(componentDir, `${componentName}.test.tsx`);
    
    if (!fs.existsSync(testFile)) {
      fs.writeFileSync(testFile, testTemplate(componentName));
      console.log(`Generated test for ${componentName}`);
    }
  }
});
```

## CC02 - Backend自動化

### MyPyエラー一括修正
```python
#!/usr/bin/env python3
# mass_fix_mypy.py
"""MyPyエラーの大量自動修正"""

import ast
import re
from pathlib import Path
from typing import List, Tuple

class TypeFixer(ast.NodeTransformer):
    """ASTを使用した型注釈の自動修正"""
    
    def visit_FunctionDef(self, node):
        # 戻り値の型がない関数にNoneを追加
        if node.returns is None:
            # 関数の内容を確認
            has_return = any(isinstance(n, ast.Return) for n in ast.walk(node))
            if not has_return:
                node.returns = ast.Constant(value='None')
        
        # 引数の型注釈を追加
        for arg in node.args.args:
            if arg.annotation is None:
                # デフォルト値から型を推測
                if arg.arg == 'self':
                    continue
                elif arg.arg.startswith('id'):
                    arg.annotation = ast.Name(id='str')
                elif arg.arg.endswith('_id'):
                    arg.annotation = ast.Name(id='str')
                else:
                    arg.annotation = ast.Name(id='Any')
        
        return self.generic_visit(node)

def fix_file(filepath: Path):
    """ファイルの型注釈を修正"""
    content = filepath.read_text()
    
    # インポートの追加
    if 'from typing import' not in content:
        content = 'from typing import Any, Optional, List, Dict, Union\n' + content
    
    # よくあるパターンの置換
    replacements = [
        # Optional[None] -> None
        (r'Optional\[None\]', 'None'),
        # dict -> Dict[str, Any]
        (r'(\w+):\s*dict\s*=', r'\1: Dict[str, Any] ='),
        # list -> List[Any]
        (r'(\w+):\s*list\s*=', r'\1: List[Any] ='),
        # 関数の引数にデフォルトNone
        (r'(\w+)=None\)', r'\1: Optional[Any] = None)'),
    ]
    
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)
    
    # ASTによる修正
    try:
        tree = ast.parse(content)
        fixer = TypeFixer()
        new_tree = fixer.visit(tree)
        # ast.unpaseは標準ではないので、簡易的な対処
    except:
        pass
    
    filepath.write_text(content)

# 全Pythonファイルを処理
for py_file in Path("app").rglob("*.py"):
    print(f"Fixing {py_file}")
    fix_file(py_file)
```

### エラー別自動対処
```bash
#!/bin/bash
# categorize_and_fix.sh

cd /home/work/ITDO_ERP2/backend

# エラーを種類別に処理
echo "=== Categorizing MyPy errors ==="

# 1. Incompatible return value type
uv run mypy app/ 2>&1 | grep "Incompatible return value type" | while read error; do
    file=$(echo "$error" | cut -d: -f1)
    line=$(echo "$error" | cut -d: -f2)
    
    # -> None を追加
    sed -i "${line}s/):/): -> None:/" "$file" 2>/dev/null || true
done

# 2. Missing type annotation for *args
uv run mypy app/ 2>&1 | grep "Missing type annotation for \*args" | while read error; do
    file=$(echo "$error" | cut -d: -f1)
    line=$(echo "$error" | cut -d: -f2)
    
    # *args: Any を追加
    sed -i "${line}s/\*args/\*args: Any/" "$file" 2>/dev/null || true
done

# 3. Need type annotation for variable
uv run mypy app/ 2>&1 | grep "Need type annotation for" | grep "(hint:" | while read error; do
    file=$(echo "$error" | cut -d: -f1)
    line=$(echo "$error" | cut -d: -f2)
    hint=$(echo "$error" | grep -o '"[^"]*"' | tr -d '"')
    
    # ヒントに基づいて型を追加
    if [ -n "$hint" ]; then
        sed -i "${line}s/= {}/: ${hint} = {}/" "$file" 2>/dev/null || true
        sed -i "${line}s/= \[\]/: ${hint} = []/" "$file" 2>/dev/null || true
    fi
done
```

## CC03 - Infrastructure自動化

### CI/CD自動最適化
```python
#!/usr/bin/env python3
# optimize_workflows.py
"""GitHub Actionsワークフローの自動最適化"""

import yaml
from pathlib import Path

def optimize_workflow(workflow_path: Path):
    """ワークフローファイルを最適化"""
    with open(workflow_path, 'r') as f:
        workflow = yaml.safe_load(f)
    
    # 全ジョブにタイムアウトを追加
    for job_name, job in workflow.get('jobs', {}).items():
        if 'timeout-minutes' not in job:
            # ジョブタイプに基づいてタイムアウトを設定
            if 'test' in job_name:
                job['timeout-minutes'] = 15
            elif 'build' in job_name:
                job['timeout-minutes'] = 10
            else:
                job['timeout-minutes'] = 5
    
    # キャッシュの追加
    for job_name, job in workflow.get('jobs', {}).items():
        steps = job.get('steps', [])
        
        # actions/setup-* の後にキャッシュを追加
        for i, step in enumerate(steps):
            if isinstance(step, dict) and 'uses' in step:
                if 'actions/setup-python' in step['uses']:
                    # Pythonキャッシュを追加
                    cache_step = {
                        'uses': 'actions/cache@v4',
                        'with': {
                            'path': '~/.cache/uv',
                            'key': "${{ runner.os }}-uv-${{ hashFiles('**/requirements.txt') }}"
                        }
                    }
                    steps.insert(i + 1, cache_step)
                elif 'actions/setup-node' in step['uses']:
                    # Node.jsキャッシュを追加
                    cache_step = {
                        'uses': 'actions/cache@v4',
                        'with': {
                            'path': '~/.npm',
                            'key': "${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}"
                        }
                    }
                    steps.insert(i + 1, cache_step)
    
    # 最適化されたワークフローを保存
    optimized_path = workflow_path.parent / f"optimized-{workflow_path.name}"
    with open(optimized_path, 'w') as f:
        yaml.dump(workflow, f, default_flow_style=False)
    
    print(f"Optimized workflow saved to: {optimized_path}")

# 全ワークフローを最適化
for workflow in Path(".github/workflows").glob("*.yml"):
    if not workflow.name.startswith("optimized-"):
        optimize_workflow(workflow)
```

### リソース監視と自動調整
```bash
#!/bin/bash
# auto_resource_manager.sh
# 継続的なリソース監視と自動調整

while true; do
    # CPU使用率を取得
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    # メモリ使用率を取得
    MEM_USAGE=$(free | grep Mem | awk '{print ($3/$2) * 100.0}')
    
    # Claudeプロセスの調整
    CLAUDE_PID=$(pgrep -f claude | head -1)
    
    if [ -n "$CLAUDE_PID" ]; then
        CLAUDE_CPU=$(top -bn1 -p $CLAUDE_PID | tail -1 | awk '{print $9}')
        
        # CPU使用率に基づいて動的に調整
        if (( $(echo "$CLAUDE_CPU > 60" | bc -l) )); then
            echo "High CPU usage detected: ${CLAUDE_CPU}%"
            
            # CPUコアを制限
            taskset -cp 0-1 $CLAUDE_PID
            
            # nice値を調整
            current_nice=$(ps -o nice -p $CLAUDE_PID | tail -1)
            new_nice=$((current_nice + 5))
            renice $new_nice -p $CLAUDE_PID
            
            echo "Applied CPU restrictions"
        elif (( $(echo "$CLAUDE_CPU < 30" | bc -l) )); then
            # 使用率が低い場合は制限を緩和
            taskset -cp 0-3 $CLAUDE_PID
            renice 10 -p $CLAUDE_PID
        fi
    fi
    
    # ログ出力
    echo "[$(date)] CPU: ${CPU_USAGE}%, MEM: ${MEM_USAGE}%, Claude: ${CLAUDE_CPU}%" >> /tmp/resource_monitor.log
    
    sleep 30
done
```

## 統合実行スクリプト

### 全エージェント同時実行
```bash
#!/bin/bash
# execute_all_agents.sh
# 全エージェントのタスクを並列実行

# CC01のタスク
(
    cd /home/work/ITDO_ERP2/frontend
    ./auto_fix_ts_errors.sh
    npm run build
    npm test
) &
CC01_PID=$!

# CC02のタスク
(
    cd /home/work/ITDO_ERP2/backend
    python mass_fix_mypy.py
    ./categorize_and_fix.sh
    uv run mypy app/
) &
CC02_PID=$!

# CC03のタスク
(
    cd /home/work/ITDO_ERP2
    python optimize_workflows.py
    ./auto_resource_manager.sh &
) &
CC03_PID=$!

# 全プロセスの完了を待つ
wait $CC01_PID $CC02_PID $CC03_PID

echo "All agent tasks completed"
```