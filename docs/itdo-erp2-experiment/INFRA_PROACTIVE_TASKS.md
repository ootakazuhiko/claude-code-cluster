# インフラ系プロアクティブタスク

## CI/CD修正

### GitHub Actions
```
.github/workflows/ci.ymlのtimeoutを30mに
```

### テスト並列化
```
pytest -n autoを設定
```

### キャッシュ追加
```
pip cacheをGitHub Actionsに追加
```

---

## Docker/Podman

### コンテナ最適化
```
Dockerfileのマルチステージビルド化
```

### compose修正
```
infra/compose-data.yamlのメモリ制限追加
```

---

## データベース

### インデックス追加
```
users.emailにインデックス
```

### マイグレーション
```
alembic revision --autogenerate
```

### 接続プール
```
pool_size=20に設定
```

---

## パフォーマンス

### Redis追加
```
キャッシュ層としてRedis設定
```

### ログ最適化
```
ログレベルをINFOに
```

### 監視追加
```
Prometheusメトリクス追加
```

---

## セキュリティ

### 依存関係更新
```
pip-audit実行
```

### シークレット管理
```
.envファイルチェック
```

### CORS設定
```
allowed_originsを設定
```

---

## 最も簡単なタスク

1. **ファイル作成**
```
.dockerignoreを作成
```

2. **1行修正**
```
Makefileにtest-fastを追加
```

3. **環境変数追加**
```
TEST_DATABASE_URL追加
```

4. **コメント追加**
```
ci.ymlにコメント追加
```

5. **フォーマット**
```
yamlファイルの整形
```