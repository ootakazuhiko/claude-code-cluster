# 🚨 CC02緊急再開指示書

## 📅 2025-07-14 18:10 JST - CC02 Backend Specialist緊急セッション開始

### ⚠️ 緊急状況分析

```yaml
CC02停止確認:
  Status: 停止状態
  Previous Focus: Issue #134 (Advanced Foundation Research)
  Critical Task: PR #97 Role Service Implementation
  
Current Repository Status:
  ✅ PR #139: CI checks mostly passing (backend-test failing)
  ❌ PR #117: Test isolation issues (CC03担当)
  🔄 Issue #134: Research完了、実装待ち
  🎯 PR #97: Role Service実装継続必要
```

### 🎯 CC02専用セッション緊急開始指示

#### 推奨初期指示文

```markdown
CC02専用バックエンド・スペシャリスト・セッションを緊急開始します。

**Role**: Backend Infrastructure Specialist
**Specialization**: FastAPI, SQLAlchemy, Permission Systems, Database Optimization
**Emergency Priority**: PR #97 - Role Service Implementation継続

**Current Emergency Situation**:
- CC02が停止状態から復旧
- Issue #134の研究フェーズが完了済み
- PR #97 Role Service実装が中断状態
- PR #139でbackend-test failing検出

**Context Setup**:
- Project: ITDO_ERP2 Backend Layer
- Working Directory: /mnt/c/work/ITDO_ERP2
- Critical Target: PR #97 Role Service完全実装
- Secondary Target: PR #139 backend-test failure解決支援
- Success Metrics: Role CRUD + Permission assignment + CI checks passing

**Current Technical Context**:
- Technology Stack: Python 3.13 + FastAPI + uv (package manager), PostgreSQL 15 + Redis 7
- Backend Framework: FastAPI with SQLAlchemy 2.0 (Mapped types)
- Testing: pytest with async support, TestClient for API testing
- Authentication: Keycloak integration for OAuth2/OpenID Connect

**Previous Context (Brief)**:
CC02は多エージェント実験でバックエンド専門エージェントとして活動し、Issue #134でAdvanced Foundation Researchを完了。現在、専用セッションに移行し、PR #97 Role Service実装に集中します。

**CC02 Expertise Required**:
Issue #134の研究成果を活用してPR #97 Role Serviceの包括的な実装を完成させ、permission matrix、role hierarchy、database optimizationを含む完全なバックエンドソリューションを提供する。

**Emergency Request**: 
PR #97の現在の実装状況を確認し、Issue #134の研究成果を適用して次の具体的な実装ステップを1つ特定して実行してください。backend-test failureの原因も調査し、必要に応じて修正してください。
```

### 🔧 技術的優先順位

```yaml
Phase 1 (今日):
  🚨 PR #97 Role Service implementation status確認
  🔧 Role CRUD operations実装
  🗄️ Database schema finalization
  
Phase 2 (明日):
  🔐 Permission assignment API実装
  👥 Role hierarchy system
  📊 Performance optimization

Phase 3 (今週):
  🛡️ Security integration
  📋 Audit logging
  🧪 Comprehensive testing
```

### 🤝 他エージェントとの協調

```yaml
CC01協調:
  🔗 User Profile Management権限統合
  📝 Frontend API contract調整
  
CC03協調:
  🗄️ Database performance最適化
  🧪 Backend testing infrastructure
  📊 CI/CD pipeline support
```

---

## 🚀 CC02緊急セッション開始準備完了

**再開タイミング**: 今すぐ実行可能
**緊急度**: HIGH - Role Service実装完成が必要
**期待効果**: Backend専門性復活 + Research→Implementation変換
**成功要因**: 明確なRole Service focus + Issue #134研究活用