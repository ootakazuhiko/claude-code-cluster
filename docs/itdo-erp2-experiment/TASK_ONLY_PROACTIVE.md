# タスクのみプロアクティブ指示

## 即座に実行可能なタスク

### 1. コード整形
```
backend/をruffでフォーマット
```

### 2. 型チェック修正
```
mypy backend/app/models/
```

### 3. テスト実行
```
pytest backend/tests/unit/
```

### 4. Import整理
```
backend/app/api/v1/users.pyのimportを整理
```

### 5. TODO確認
```
grep -r "TODO" backend/
```

---

## ファイル作成タスク

### 1. 新規コンポーネント
```
frontend/src/components/ProfileEdit.tsx
```

### 2. 新規テスト
```
backend/tests/unit/test_role_service.py
```

### 3. 新規API
```
backend/app/api/v1/profiles.py
```

---

## 修正タスク

### 1. エラー修正
```
TypeError in user.py line 45を修正
```

### 2. Warning解消
```
Deprecation warningを解消
```

### 3. Lint修正
```
ESLintエラーを修正
```

---

## 実装タスク

### 1. 関数追加
```
get_user_profile()を実装
```

### 2. エンドポイント追加
```
GET /api/v1/users/{id}/profile
```

### 3. バリデーション追加
```
email形式チェックを追加
```

---

## 最適化タスク

### 1. クエリ最適化
```
N+1問題を解決
```

### 2. キャッシュ追加
```
user_profileにキャッシュ追加
```

### 3. インデックス追加
```
created_atにインデックス追加
```