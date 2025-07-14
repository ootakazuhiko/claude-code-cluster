# React/TypeScriptプロアクティブタスク

## コンポーネント作成

### ボタン
```
Button.tsxを作成
```

### フォーム
```
LoginForm.tsxを作成
```

### カード
```
UserCard.tsxを作成
```

---

## 型定義

### User型
```
interface User {
  id: number
  name: string
}
```

### Props型
```
type ButtonProps = {
  onClick: () => void
}
```

---

## スタイル追加

### CSS Module
```
Button.module.cssを作成
```

### Tailwind
```
className="bg-blue-500"
```

### インライン
```
style={{ color: 'red' }}
```

---

## Hook作成

### useState
```
const [count, setCount] = useState(0)
```

### useEffect
```
useEffect(() => {}, [])
```

### カスタムHook
```
useUser.tsを作成
```

---

## 修正タスク

### TypeScriptエラー
```
Property 'name' does not exist を修正
```

### ESLint警告
```
React Hook useEffect has a missing dependency を修正
```

### Import修正
```
import Reactを追加
```

---

## 最も簡単なタスク

1. **console.log追加**
```
console.log('test')
```

2. **コメント追加**
```
// TODO: implement
```

3. **空コンポーネント**
```
const Test = () => null
```

4. **div追加**
```
<div>Hello</div>
```

5. **export追加**
```
export default
```