# 🔧 エージェント安定性フレームワーク

## 📅 2025-07-14 18:15 JST - 多重停止対応と安定性向上

### 🚨 問題分析

```yaml
停止パターン分析:
  CC02: 1st stop (多エージェント→専用移行) → 2nd stop (専用セッション直後)
  CC03: 1st stop (多エージェント終了) → 2nd stop (専用セッション直後)
  CC01: 継続安定動作中
  
共通要因:
  ❌ 専用セッション移行時の不安定性
  ❌ Context切り替え時の問題
  ❌ 複雑な指示文の処理困難
```

### 🔧 安定性向上対策

#### A. 指示文最適化

```yaml
Before (複雑):
  - 長文の技術的context
  - 多重priority設定
  - 複雑なsession定義
  
After (簡潔):
  - 明確なWorking Directory
  - Single primary task
  - Immediate actionable request
  - 具体的success criteria
```

#### B. セッション起動強化

```yaml
Essential Context Only:
  ✅ Working Directory: /mnt/c/work/ITDO_ERP2
  ✅ GitHub Repository: https://github.com/itdojp/ITDO_ERP2
  ✅ Current Branch: feature/claude-usage-optimization
  ✅ Single Primary Task: 具体的Issue/PR
  ✅ Clear Role Definition: Backend/Frontend/Infrastructure
  
避けるべき要素:
  ❌ 長文の過去context
  ❌ 複数task同時指定
  ❌ 抽象的な目標設定
  ❌ 複雑なsession hierarchy
```

### 📋 安定化済み指示テンプレート

#### CC02安定版テンプレート
```markdown
CC02専用バックエンド・セッション開始。

**Context**: /mnt/c/work/ITDO_ERP2
**Role**: Backend Specialist (FastAPI + SQLAlchemy)
**Task**: PR #97 Role Service Implementation
**Request**: PR #97の実装状況確認し、次のステップ1つ実行してください。
```

#### CC03安定版テンプレート
```markdown
CC03専用インフラ・セッション開始。

**Context**: /mnt/c/work/ITDO_ERP2
**Role**: Infrastructure Specialist (CI/CD + Testing)
**Task**: Issue #138 Test Database Isolation
**Request**: PR #117のCI失敗分析し、修正ステップ1つ実行してください。
```

### 🎯 継続性保証メカニズム

#### 1. 段階的復旧
```yaml
Phase 1: 最小Context起動
  - Working Directory指定のみ
  - Single task focus
  - Immediate request

Phase 2: 安定性確認
  - 基本動作確認
  - Simple task実行
  - Response quality評価

Phase 3: 段階的拡張
  - Additional context追加
  - Complex task assignment
  - Full specialization活用
```

#### 2. 冗長性確保
```yaml
Primary Strategy: 専用セッション
Backup Strategy: 統合セッション復帰
Emergency Strategy: CC01単独継続
Monitoring: GitHub Activity tracking
```

### 📊 効果測定

```yaml
安定性指標:
  ✅ Session survival rate
  ✅ Task completion consistency
  ✅ Response quality maintenance
  ✅ Error recovery capability
  
Performance指標:
  ✅ Implementation速度
  ✅ Code quality維持
  ✅ CI/CD pipeline安定性
  ✅ Cross-agent coordination効率
```

---

## 🚀 安定性フレームワーク適用準備完了

**適用方針**: 簡潔・明確・単一focus
**期待効果**: エージェント停止率大幅削減
**継続監視**: GitHub activity tracking