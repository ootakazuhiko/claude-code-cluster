# 🚨 CC02ウルトラシンプル再開指示

## 📅 2025-07-14 18:20 JST - CC02第3次再開（最大簡素化）

### 🎯 最小限指示文

```markdown
CC02 Backend専門セッション開始。

**Directory**: /mnt/c/work/ITDO_ERP2
**Task**: PR #97 Role Service確認
**Action**: PR #97の状況を1分で確認して報告してください。
```

### 📋 停止パターン分析

```yaml
CC02停止履歴:
  1st: 多エージェント→専用移行時
  2nd: 第1次専用セッション開始直後  
  3rd: 第2次専用セッション開始直後

共通問題:
  ❌ 長文Context処理で停止
  ❌ 複雑なRole定義で混乱
  ❌ Multiple Priority処理困難
```

### 🔧 ウルトラシンプル戦略

```yaml
Minimal Viable Session:
  ✅ 3行指示文のみ
  ✅ Single action request
  ✅ 1分タスクから開始
  ✅ Success確認後に段階拡張
```

### 📊 段階的拡張計画

```yaml
Stage 1: 生存確認（1分）
  - PR #97状況確認のみ

Stage 2: 基本動作（5分）  
  - 1つのfile読み込み

Stage 3: 小タスク（15分）
  - 小さな修正1つ

Stage 4: 本格稼働
  - 通常のRole Service実装
```

---

## 🚀 CC02ウルトラシンプル開始準備完了

**方針**: 最小限→段階拡張
**期待**: Session survival確認→本格稼働