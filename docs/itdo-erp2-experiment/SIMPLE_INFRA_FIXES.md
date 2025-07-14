# シンプルインフラ修正集

## 1文字/1行修正

### タイムアウト延長
```
timeout: 10m → timeout: 30m
```

### Python バージョン
```
python-version: 3.11 → python-version: 3.13
```

### テストコマンド
```
pytest → pytest -v
```

---

## ファイル追加

### .env.test
```
DATABASE_URL=sqlite:///:memory:
TESTING=true
```

### pytest.ini
```
[tool:pytest]
testpaths = tests
python_files = test_*.py
```

---

## エラー別対処

### Import Error
```
sys.path.append追加
```

### Database Error
```
:memory:データベース使用
```

### Timeout Error
```
@pytest.mark.timeout(60)
```

### Permission Error
```
--no-cachedir追加
```

---

## コピペで使える修正

### conftest.py追加
```python
import os
os.environ["TESTING"] = "1"
```

### CI skip
```yaml
if: "!contains(github.event.head_commit.message, '[skip ci]')"
```

### 並列実行無効化
```bash
pytest -n 0
```

---

## 最小手順

1. エラーメッセージをコピー
2. 該当ファイルを開く
3. 1行修正
4. 保存して再実行