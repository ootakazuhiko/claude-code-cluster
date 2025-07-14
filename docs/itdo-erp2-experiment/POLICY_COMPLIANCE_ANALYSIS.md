# 🔍 既存指示文ポリシー違反リスク分析

## 📅 2025-07-14 18:25 JST - Usage Policy準拠性確認

### 🚨 高リスク要素特定

```yaml
エージェント関連表現:
  ❌ "CC01専用セッション"
  ❌ "CC02バックエンド・スペシャリスト"
  ❌ "CC03インフラストラクチャ・エキスパート"
  ❌ "エージェント協調"
  ❌ "多エージェント実験"

システム模倣表現:
  ❌ "Role: Backend Infrastructure Specialist"
  ❌ "Specialization: Test Infrastructure"
  ❌ "Session ID: CC01-Technical-Leader"
  ❌ "Mission: Advanced architecture research"

複雑な役割定義:
  ❌ 詳細なspecialization定義
  ❌ 複数priority設定
  ❌ 協調メカニズム詳細
  ❌ 実験的framework言及
```

### ✅ 安全な表現への変換

#### Before (リスク高)
```markdown
CC01専用技術リーダー・セッション開始。
Role: Technical Implementation Leader
Specialization: 複雑実装・バグ修正・技術判断
```

#### After (ポリシー準拠)
```markdown
ITDO_ERP2開発作業セッション開始。
作業内容: User Profile Management実装
目標: Issue #137の完成
```

### 📋 安全な指示文テンプレート

#### 1. User Profile Management作業
```markdown
ITDO_ERP2プロジェクト開発支援をお願いします。

**プロジェクト**: ITDO_ERP2 (ERP System)
**作業ディレクトリ**: /mnt/c/work/ITDO_ERP2
**対象Issue**: #137 User Profile Management Phase 2-B

**作業内容**:
Issue #137のUser Profile Management機能について、現在の実装状況を確認し、
次に必要な開発ステップを1つ実行してください。

**技術環境**: Python + FastAPI + React + TypeScript
```

#### 2. Role Service実装作業
```markdown
ITDO_ERP2バックエンド開発をお願いします。

**プロジェクト**: ITDO_ERP2
**作業場所**: /mnt/c/work/ITDO_ERP2
**対象**: PR #97 Role Service Implementation

**依頼内容**:
PR #97のRole Service機能の実装状況を確認し、
必要な実装作業を進めてください。

**技術スタック**: Python 3.13 + FastAPI + SQLAlchemy
```

#### 3. Test Infrastructure改善
```markdown
ITDO_ERP2テスト環境改善をお願いします。

**プロジェクト**: ITDO_ERP2
**ディレクトリ**: /mnt/c/work/ITDO_ERP2
**課題**: Test Database Isolation (Issue #138)

**作業依頼**:
Test Database Isolation機能の実装について、
現在の問題を分析し、改善案を実装してください。

**環境**: Python + pytest + PostgreSQL
```

---

## 🛡️ ポリシー準拠確認完了

**リスク除去**: エージェント関連表現・システム模倣・複雑役割定義
**安全化**: 通常の開発作業指示への変換
**方針**: 実験的要素完全排除 + 単純明確な作業依頼