# シンプルReactパターン集

## コピペで使える最小コンポーネント

### 関数コンポーネント
```tsx
function Hello() {
  return <div>Hello</div>
}
```

### アロー関数
```tsx
const Hello = () => <div>Hello</div>
```

### Props付き
```tsx
const Hello = ({ name }) => <div>Hello {name}</div>
```

### TypeScript版
```tsx
const Hello: React.FC<{ name: string }> = ({ name }) => {
  return <div>Hello {name}</div>
}
```

---

## 1行で書けるもの

### ボタン
```tsx
<button onClick={() => alert('click')}>Click</button>
```

### 入力
```tsx
<input onChange={e => console.log(e.target.value)} />
```

### リスト
```tsx
{[1,2,3].map(n => <li key={n}>{n}</li>)}
```

---

## エラー修正パターン

### any型修正
```tsx
// Before
const user: any
// After  
const user: { name: string }
```

### key prop追加
```tsx
// Before
items.map(item => <div>{item}</div>)
// After
items.map((item, i) => <div key={i}>{item}</div>)
```

### import修正
```tsx
// 追加
import React from 'react'
```

---

## 最小API呼び出し

### fetch
```tsx
fetch('/api/users').then(r => r.json())
```

### async/await
```tsx
const data = await fetch('/api/users').then(r => r.json())
```

### useEffect内
```tsx
useEffect(() => {
  fetch('/api/users')
}, [])
```

---

## デバッグ用

### 値確認
```tsx
<pre>{JSON.stringify(data, null, 2)}</pre>
```

### 条件分岐
```tsx
{loading ? 'Loading...' : 'Done'}
```

### エラー表示
```tsx
{error && <div>Error: {error}</div>}
```