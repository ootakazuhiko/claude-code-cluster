# エージェント間協調タスク - 2025年1月19日

## 現在の状況サマリー
- CC01: UIコンポーネント開発中（TypeScriptエラー修正）
- CC02: PR #222対応で90時間以上稼働（緊急対応必要）
- CC03: CPU 73%で高負荷状態（最適化必要）

## 協調タスクリスト

### 1. CC02支援プロジェクト（最優先）

#### CC03からCC02への支援
```yaml
# CC03が作成: .github/workflows/mypy-helper.yml
name: MyPy Progress Tracker
on:
  push:
    branches: [fix/cc02-type-annotations]
    
jobs:
  track-progress:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        run: |
          curl -LsSf https://astral.sh/uv/install.sh | sh
          
      - name: Count Errors
        id: mypy
        run: |
          cd backend
          ERROR_COUNT=$(uv run mypy app/ 2>&1 | grep -c "error:" || echo "0")
          echo "errors=$ERROR_COUNT" >> $GITHUB_OUTPUT
          
          # 進捗をPRコメントに投稿
          if [ -n "${{ github.event.pull_request.number }}" ]; then
            gh pr comment ${{ github.event.pull_request.number }} \
              --body "MyPy Error Count: $ERROR_COUNT"
          fi
          
      - name: Error Analysis
        run: |
          cd backend
          uv run mypy app/ 2>&1 | grep "error:" | \
            cut -d: -f4- | sort | uniq -c | sort -nr > error_summary.txt
          
          echo "### Top Error Types" >> $GITHUB_STEP_SUMMARY
          head -10 error_summary.txt >> $GITHUB_STEP_SUMMARY
```

#### CC01からCC02への支援
```typescript
// CC01が提供: frontend/src/types/api-contracts.ts
// バックエンドとの共通型定義

export interface ApiResponse<T> {
  data: T;
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };
  meta?: {
    timestamp: string;
    version: string;
  };
}

export interface PaginatedResponse<T> extends ApiResponse<T[]> {
  pagination: {
    page: number;
    pageSize: number;
    totalCount: number;
    totalPages: number;
  };
}

// 具体的なエンドポイント型
export interface UserResponse {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  roles: string[];
  organizationId: string;
  departmentId?: string;
}
```

### 2. リソース最適化プロジェクト

#### 全エージェント向けリソース監視
```bash
#!/bin/bash
# monitor-all-agents.sh
# CC03が管理、全エージェントで実行

AGENT_NAME=${AGENT_NAME:-Unknown}
LOG_FILE="/tmp/agent_${AGENT_NAME}_metrics.log"

while true; do
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    CPU=$(top -bn1 | grep claude | awk '{print $9}' | head -1)
    MEM=$(ps aux | grep claude | grep -v grep | awk '{print $4}' | head -1)
    
    # JSON形式で記録
    cat >> "$LOG_FILE" << EOF
{"timestamp":"$TIMESTAMP","agent":"$AGENT_NAME","cpu":$CPU,"memory":$MEM}
EOF
    
    # Webhook経由で中央に報告（Hookシステム使用時）
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST "$WEBHOOK_URL" \
          -H "Content-Type: application/json" \
          -d "{\"type\":\"metrics\",\"agent\":\"$AGENT_NAME\",\"cpu\":$CPU,\"memory\":$MEM}"
    fi
    
    sleep 300  # 5分ごと
done
```

### 3. 統合テストプロジェクト

#### フロントエンド・バックエンド統合テスト
```typescript
// CC01とCC02が共同作成: tests/integration/api-contract.test.ts
import { describe, it, expect } from 'vitest';
import type { UserResponse } from '@/types/api-contracts';

describe('API Contract Tests', () => {
  it('should match user response schema', async () => {
    const response = await fetch('/api/v1/users/me');
    const data: UserResponse = await response.json();
    
    // 型の整合性を確認
    expect(data).toHaveProperty('id');
    expect(data).toHaveProperty('email');
    expect(data.roles).toBeInstanceOf(Array);
    
    // CC02のPydanticスキーマと一致することを確認
  });
});
```

### 4. ドキュメント統合プロジェクト

#### 共同作成: API仕様書
```markdown
# ITDO ERP2 API Specification

## Overview
This document is maintained jointly by:
- CC01: Frontend perspective and TypeScript types
- CC02: Backend implementation and Pydantic schemas  
- CC03: Infrastructure and deployment considerations

## Endpoints

### Authentication
| Method | Path | Request | Response | Owner |
|--------|------|---------|----------|-------|
| POST | /api/v1/auth/login | LoginRequest | TokenResponse | CC02 |
| POST | /api/v1/auth/refresh | RefreshRequest | TokenResponse | CC02 |

### Users
| Method | Path | Request | Response | Owner |
|--------|------|---------|----------|-------|
| GET | /api/v1/users | - | UserResponse[] | CC02 |
| POST | /api/v1/users | CreateUserRequest | UserResponse | CC02 |

## Type Definitions

### Frontend (TypeScript)
\`\`\`typescript
// Maintained by CC01
interface LoginRequest {
  email: string;
  password: string;
}
\`\`\`

### Backend (Pydantic)
\`\`\`python
# Maintained by CC02
class LoginRequest(BaseModel):
    email: EmailStr
    password: SecretStr
\`\`\`

## Infrastructure
Maintained by CC03:
- Rate limiting: 100 req/min per IP
- Response time SLA: <200ms
- Caching strategy: Redis with 5min TTL
```

## 実行スケジュール

### 即時（今すぐ）
1. CC03: CC02用の軽量MyPyヘルパーワークフロー作成
2. CC02: 作業セッションの保存と休憩
3. CC01: API契約型の定義開始

### 2時間以内
1. 全エージェント: リソース監視スクリプトの導入
2. CC01 & CC02: 型定義の整合性確認
3. CC03: CPU使用率を50%以下に削減

### 本日中
1. API仕様書の初版作成
2. 統合テストの基盤構築
3. 進捗ダッシュボードの設置

## 成功指標
- CC02のMyPyエラー: 50%削減
- CC03のCPU使用率: 50%以下
- CC01のTypeScriptエラー: 0
- エージェント間の型整合性: 100%

## コミュニケーションプロトコル
1. 6時間ごとに進捗報告
2. ブロッカーは即座に共有
3. 成功事例を文書化
4. 相互レビューの実施