# CC03最小インフラ指示

## 最優先試行

```
.github/workflows/ci.ymlを修正
```

## 代替1

```
pytest実行時のエラーを修正
```

## 代替2

```
テストのタイムアウトを解決
```

## 代替3

```
conftest.pyでデータベース設定を修正
```

## 代替4（具体的）

```
DATABASE_URL = "sqlite:///:memory:"
これをconftest.pyに追加
```