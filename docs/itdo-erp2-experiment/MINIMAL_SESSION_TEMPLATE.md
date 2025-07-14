# 📋 最小セッション起動テンプレート

## 📅 2025-07-14 18:20 JST - Ultra Minimal Session Framework

### 🎯 CC02停止問題からの学習

```yaml
問題パターン:
  ❌ 長文Context → 処理困難で停止
  ❌ 複雑Role定義 → 混乱で停止  
  ❌ Multiple Priority → 判断困難で停止

解決アプローチ:
  ✅ 最小限指示文（3行以内）
  ✅ Single Action Request
  ✅ 1分タスクから開始
  ✅ 段階的拡張戦略
```

### 📋 ウルトラミニマルテンプレート

#### Template A: 生存確認版
```markdown
[Agent] Session開始。
Directory: /mnt/c/work/ITDO_ERP2
Action: [Task]の状況を1分で確認して報告してください。
```

#### Template B: 基本動作版
```markdown
[Agent] 基本動作確認。
Task: [File]を読んでください。
Report: 内容を3行で要約してください。
```

#### Template C: 小タスク版
```markdown
[Agent] 小タスク実行。
Target: [Specific Issue/PR]
Action: 1つの小さな修正を実行してください。
```

### 🔄 段階的拡張戦略

```yaml
Stage 1 (1分): 生存確認
  - Template A使用
  - 基本応答確認
  - Session stability確認

Stage 2 (5分): 基本動作
  - Template B使用  
  - File読み込み確認
  - Simple task実行

Stage 3 (15分): 小タスク
  - Template C使用
  - 実際の作業実行
  - Quality確認

Stage 4 (通常): 本格稼働
  - 通常の専門性発揮
  - Complex task assignment
  - Full performance delivery
```

### 📊 成功基準

```yaml
Session Survival:
  ✅ Stage 1完了 → Stage 2へ
  ✅ Stage 2完了 → Stage 3へ
  ✅ Stage 3完了 → Stage 4へ
  
Quality Maintenance:
  ✅ 各stageでの応答品質確認
  ✅ Technical accuracy維持
  ✅ Gradual complexity increase
```

---

## 🚀 最小セッション戦略準備完了

**適用対象**: 不安定エージェント（特にCC02）
**期待効果**: Session survival rate大幅向上
**拡張方針**: 安定性確認後の段階的complexity増加