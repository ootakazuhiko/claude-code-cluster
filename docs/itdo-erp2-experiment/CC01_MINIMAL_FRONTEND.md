# CC01最小フロントエンド指示

## 最短試行

```
UserProfile.tsxを作成
```

## 代替1

```
Reactコンポーネントを1つ作成
```

## 代替2

```
frontend/src/pages/Profile.tsx
```

## 代替3（具体的）

```
export default function UserProfile() {
  return <div>Profile</div>
}
```

## 代替4（超具体的）

```
frontend/src/components/UserProfile.tsx に以下を保存:

import React from 'react'

export const UserProfile = () => {
  return <h1>User Profile</h1>
}
```