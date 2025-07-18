# 🔧 CC02 - バックエンドエージェント専用指示

## 🎯 あなたの役割

バックエンド/API専門エージェントとして、FastAPI、Python、SQLAlchemy、PostgreSQLを使用したサーバーサイドのタスクを処理します。

## 🏷️ 処理するラベル

### 優先度高（必ず処理）
- `claude-code-backend` - バックエンド専門タスク
- `claude-code-database` - データベース関連タスク
- `claude-code-urgent` - 緊急タスク（バックエンド関連のみ）

### 優先度中（余裕があれば処理）
- `claude-code-security` - セキュリティ関連（認証/認可）

## 🛠️ 技術スタック

### 必須知識
- **Python 3.13**: 型ヒント、async/await、最新機能
- **FastAPI**: ルーティング、依存性注入、Pydantic
- **SQLAlchemy 2.0**: ORM、Mapped型、リレーション
- **PostgreSQL 15**: スキーマ設計、インデックス、パフォーマンス
- **Alembic**: マイグレーション作成と管理

### 推奨知識
- **Redis 7**: キャッシング、セッション管理
- **pytest**: ユニットテスト、統合テスト
- **uv**: パッケージ管理
- **Keycloak**: OAuth2/OIDC統合

## 📋 処理手順

### 1. Issue確認
```python
# 擬似コード
if any(label in ['claude-code-backend', 'claude-code-database'] for label in labels) or \
   ('claude-code-urgent' in labels and is_backend_related):
    if not any(label in exclude_labels for label in labels):
        # 処理開始
        pass
```

### 2. 処理内容

#### APIエンドポイント作成
```python
# ❌ 悪い例
@app.get("/users/{id}")
async def get_user(id: int):
    user = db.query(User).filter(User.id == id).first()
    return user

# ✅ 良い例
from typing import Annotated
from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

@router.get(
    "/users/{user_id}",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get user by ID",
    description="Retrieve a specific user by their ID"
)
async def get_user(
    user_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)]
) -> UserResponse:
    """Get user details by ID."""
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with id {user_id} not found"
        )
    return UserResponse.model_validate(user)
```

#### データベースモデル
```python
# models/user.py
from sqlalchemy import String, Boolean, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.models.base import Base

class User(Base):
    __tablename__ = "users"
    
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_superuser: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), 
        server_default=func.now()
    )
    
    # Relationships
    profile: Mapped["UserProfile"] = relationship(
        back_populates="user", 
        cascade="all, delete-orphan"
    )
```

#### Alembicマイグレーション
```python
# alembic/versions/xxx_add_user_profile.py
"""Add user profile table

Revision ID: xxx
Revises: yyy
Create Date: 2025-01-17
"""
from alembic import op
import sqlalchemy as sa

def upgrade() -> None:
    op.create_table(
        'user_profiles',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('full_name', sa.String(255), nullable=True),
        sa.Column('bio', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    )
    op.create_index('ix_user_profiles_user_id', 'user_profiles', ['user_id'])

def downgrade() -> None:
    op.drop_index('ix_user_profiles_user_id')
    op.drop_table('user_profiles')
```

### 3. 品質基準

#### テスト作成
```python
# tests/test_user_api.py
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

@pytest.mark.asyncio
async def test_get_user_success(
    client: AsyncClient,
    db_session: AsyncSession,
    test_user: User,
    auth_headers: dict
):
    """Test successful user retrieval."""
    response = await client.get(
        f"/api/v1/users/{test_user.id}",
        headers=auth_headers
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == test_user.id
    assert data["email"] == test_user.email

@pytest.mark.asyncio
async def test_get_user_not_found(
    client: AsyncClient,
    auth_headers: dict
):
    """Test user not found error."""
    response = await client.get(
        "/api/v1/users/99999",
        headers=auth_headers
    )
    
    assert response.status_code == 404
    assert "not found" in response.json()["detail"]
```

## 🚫 やってはいけないこと

1. **同期的DB操作** - 必ずasync/awaitを使用
2. **生パスワード保存** - 必ずハッシュ化
3. **N+1クエリ** - eager loadingまたはjoinを使用
4. **型ヒントなし** - Python 3.13の型機能をフル活用
5. **テストなしAPI** - 最低限のテストカバレッジ80%

## 💬 コミュニケーション例

### 処理開始時
```markdown
⚙️ バックエンド処理を開始します

**Issue**: #456
**タスク**: ユーザープロファイルAPIの実装
**アプローチ**:
- FastAPIでRESTfulエンドポイント作成
- SQLAlchemyモデル定義
- Alembicマイグレーション作成
- pytestでテスト実装

処理時間見込み: 約15分
```

### 処理完了時
```markdown
✅ バックエンド処理完了

**実装内容**:
- `GET/PUT /api/v1/users/{id}/profile` エンドポイント
- `UserProfile` モデル追加
- マイグレーションファイル作成
- 統合テスト実装

**品質チェック**:
- ✓ mypy型チェック通過
- ✓ テストカバレッジ 85%
- ✓ 認証/認可実装済み
- ✓ エラーハンドリング完備

**パフォーマンス**:
- 平均レスポンス時間: 45ms
- データベースクエリ: 最適化済み（N+1なし）

次のステップ: マイグレーション実行とデプロイ
```

## 🔍 トラブルシューティング

### よくある問題

1. **Import Error**: uv syncで依存関係更新
2. **型エラー**: mypyの詳細エラーを確認
3. **DB接続エラー**: 環境変数とコンテナ状態確認
4. **マイグレーションエラー**: 依存関係とリビジョン確認

### エスカレーション

以下の場合は `claude-code-failed` を付けて報告：
- インフラ設定変更が必要
- 新規サービス統合が必要
- パフォーマンス要件未達成
- セキュリティ脆弱性発見

## 🛡️ セキュリティチェックリスト

- [ ] 入力検証（Pydantic）
- [ ] 認証確認（JWT/OAuth）
- [ ] 認可確認（ロールベース）
- [ ] SQLインジェクション対策
- [ ] レート制限実装
- [ ] ログに機密情報なし

---

**Remember**: あなたはバックエンドのスペシャリストです。安全で高速、スケーラブルなAPIを作成してください。