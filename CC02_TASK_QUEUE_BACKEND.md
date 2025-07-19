# CC02 Backend タスクキュー

## 優先度: 最高

### 1. MyPy完全対応 - 自動修正スクリプト
```python
#!/usr/bin/env python3
# auto_fix_all_mypy.py
import os
import re
import ast
from pathlib import Path
from typing import Dict, List, Tuple, Any

class ComprehensiveTypeFixer:
    def __init__(self):
        self.common_imports = [
            "from typing import Any, Dict, List, Optional, Union, Tuple, Set, Type, Callable",
            "from typing import Literal, Protocol, TypedDict, cast, overload",
            "from collections.abc import Sequence, Mapping, Iterable",
            "from datetime import datetime, date, timedelta",
            "from decimal import Decimal",
            "from uuid import UUID"
        ]
    
    def fix_file(self, filepath: Path) -> None:
        content = filepath.read_text()
        
        # 1. Import追加
        if 'from typing import' not in content:
            content = '\n'.join(self.common_imports) + '\n\n' + content
        
        # 2. 関数シグネチャの修正
        content = self._fix_function_signatures(content)
        
        # 3. 変数アノテーションの追加
        content = self._fix_variable_annotations(content)
        
        # 4. クラス属性の型注釈
        content = self._fix_class_attributes(content)
        
        filepath.write_text(content)
    
    def _fix_function_signatures(self, content: str) -> str:
        # 戻り値の型がない関数に -> None を追加
        content = re.sub(
            r'def\s+(\w+)\s*\([^)]*\)\s*:',
            r'def \1(\g<0>) -> None:',
            content
        )
        
        # self引数の後の引数に型を追加
        content = re.sub(
            r'def\s+\w+\s*\(self,\s*(\w+)\)',
            r'def \g<0>(self, \1: Any)',
            content
        )
        
        return content
    
    def _fix_variable_annotations(self, content: str) -> str:
        # 辞書の初期化
        content = re.sub(r'(\w+)\s*=\s*{}', r'\1: Dict[str, Any] = {}', content)
        content = re.sub(r'(\w+)\s*=\s*\[\]', r'\1: List[Any] = []', content)
        content = re.sub(r'(\w+)\s*=\s*set\(\)', r'\1: Set[Any] = set()', content)
        
        return content
    
    def _fix_class_attributes(self, content: str) -> str:
        # クラス属性の型注釈
        lines = content.split('\n')
        in_class = False
        class_indent = 0
        new_lines = []
        
        for line in lines:
            if re.match(r'^class\s+\w+', line):
                in_class = True
                class_indent = len(line) - len(line.lstrip())
            elif in_class and line.strip() and not line[class_indent:class_indent+1].isspace():
                in_class = False
            
            if in_class and re.match(r'^\s+(\w+)\s*=\s*', line):
                # クラス属性に型注釈を追加
                line = re.sub(r'(\w+)\s*=\s*None', r'\1: Optional[Any] = None', line)
                line = re.sub(r'(\w+)\s*=\s*(\d+)', r'\1: int = \2', line)
                line = re.sub(r'(\w+)\s*=\s*"([^"]*)"', r'\1: str = "\2"', line)
            
            new_lines.append(line)
        
        return '\n'.join(new_lines)

# 実行
fixer = ComprehensiveTypeFixer()
for py_file in Path("app").rglob("*.py"):
    print(f"Fixing {py_file}")
    fixer.fix_file(py_file)
```

### 2. Pydanticモデルの完全型付け
```python
# app/schemas/base.py
from pydantic import BaseModel, ConfigDict, Field, validator
from typing import Optional, Dict, Any, List
from datetime import datetime
from uuid import UUID

class TimestampedModel(BaseModel):
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    
    model_config = ConfigDict(
        from_attributes=True,
        validate_assignment=True,
        arbitrary_types_allowed=True,
        json_encoders={
            datetime: lambda v: v.isoformat(),
            UUID: lambda v: str(v),
        }
    )

class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    page_size: int
    total_pages: int
    
    @validator('total_pages', always=True)
    def calculate_total_pages(cls, v: int, values: Dict[str, Any]) -> int:
        if 'total' in values and 'page_size' in values:
            return (values['total'] + values['page_size'] - 1) // values['page_size']
        return 0
```

### 3. SQLAlchemyモデルの型注釈完全対応
```python
# app/models/base.py
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy import DateTime, func
from datetime import datetime
from typing import Optional
import uuid

class Base(DeclarativeBase):
    pass

class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False
    )

class UUIDMixin:
    id: Mapped[str] = mapped_column(
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )
```

## 優先度: 高

### 4. APIエンドポイントの完全型付け
```python
# app/api/v1/base.py
from typing import TypeVar, Generic, Type, Optional, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel

T = TypeVar('T', bound=BaseModel)
ModelType = TypeVar('ModelType')
CreateSchemaType = TypeVar('CreateSchemaType', bound=BaseModel)
UpdateSchemaType = TypeVar('UpdateSchemaType', bound=BaseModel)

class CRUDRouter(Generic[ModelType, CreateSchemaType, UpdateSchemaType, T]):
    def __init__(
        self,
        model: Type[ModelType],
        create_schema: Type[CreateSchemaType],
        update_schema: Type[UpdateSchemaType],
        response_schema: Type[T],
        prefix: str,
        tags: Optional[List[str]] = None
    ):
        self.model = model
        self.create_schema = create_schema
        self.update_schema = update_schema
        self.response_schema = response_schema
        self.router = APIRouter(prefix=prefix, tags=tags or [])
        self._register_routes()
    
    def _register_routes(self) -> None:
        self.router.add_api_route(
            "/",
            self.get_multi,
            methods=["GET"],
            response_model=List[self.response_schema]
        )
        self.router.add_api_route(
            "/{id}",
            self.get_one,
            methods=["GET"],
            response_model=self.response_schema
        )
        # ... 他のルート
```

### 5. サービス層の型安全性
```python
# app/services/base.py
from typing import TypeVar, Generic, Type, Optional, List, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import select, func
from app.models.base import Base

ModelType = TypeVar('ModelType', bound=Base)

class BaseService(Generic[ModelType]):
    def __init__(self, model: Type[ModelType]):
        self.model = model
    
    async def get(self, db: Session, id: str) -> Optional[ModelType]:
        stmt = select(self.model).where(self.model.id == id)
        result = db.execute(stmt)
        return result.scalar_one_or_none()
    
    async def get_multi(
        self,
        db: Session,
        *,
        skip: int = 0,
        limit: int = 100,
        filters: Optional[Dict[str, Any]] = None
    ) -> List[ModelType]:
        stmt = select(self.model).offset(skip).limit(limit)
        
        if filters:
            for key, value in filters.items():
                if hasattr(self.model, key):
                    stmt = stmt.where(getattr(self.model, key) == value)
        
        result = db.execute(stmt)
        return list(result.scalars().all())
```

### 6. 依存性注入の型付け
```python
# app/dependencies.py
from typing import Generator, Annotated
from fastapi import Depends, HTTPException, status
from sqlalchemy.orm import Session
from jose import JWTError, jwt
from app.core.database import SessionLocal
from app.core.config import settings
from app.models.user import User

def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

DbDependency = Annotated[Session, Depends(get_db)]

async def get_current_user(
    db: DbDependency,
    token: Annotated[str, Depends(oauth2_scheme)]
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(User).filter(User.email == username).first()
    if user is None:
        raise credentials_exception
    
    return user

CurrentUser = Annotated[User, Depends(get_current_user)]
```

### 7. カスタムバリデーター
```python
# app/validators.py
from typing import Any, Dict, Optional
from pydantic import validator, root_validator
from email_validator import validate_email, EmailNotValidError

class EmailValidator:
    @classmethod
    def validate_email(cls, v: str) -> str:
        try:
            validation = validate_email(v)
            return validation.email
        except EmailNotValidError:
            raise ValueError('Invalid email address')

class PasswordValidator:
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters')
        if not any(c.isupper() for c in v):
            raise ValueError('Password must contain uppercase letter')
        if not any(c.islower() for c in v):
            raise ValueError('Password must contain lowercase letter')
        if not any(c.isdigit() for c in v):
            raise ValueError('Password must contain digit')
        return v
```

### 8. エラーハンドリングの型付け
```python
# app/exceptions.py
from typing import Any, Dict, Optional, Union
from fastapi import HTTPException, status

class BaseAPIException(HTTPException):
    def __init__(
        self,
        status_code: int,
        detail: str,
        headers: Optional[Dict[str, str]] = None,
        error_code: Optional[str] = None
    ):
        super().__init__(status_code=status_code, detail=detail, headers=headers)
        self.error_code = error_code

class NotFoundError(BaseAPIException):
    def __init__(self, resource: str, id: Union[str, int]):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"{resource} with id {id} not found",
            error_code="RESOURCE_NOT_FOUND"
        )

class ValidationError(BaseAPIException):
    def __init__(self, field: str, message: str):
        super().__init__(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Validation error on field '{field}': {message}",
            error_code="VALIDATION_ERROR"
        )
```

## 優先度: 中

### 9. テスト用フィクスチャの型付け
```python
# tests/conftest.py
from typing import Generator, Dict, Any
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from fastapi.testclient import TestClient
from app.main import app
from app.core.database import Base
from app.dependencies import get_db

@pytest.fixture(scope="session")
def engine():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    yield engine
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db(engine) -> Generator[Session, None, None]:
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    session = SessionLocal()
    yield session
    session.rollback()
    session.close()

@pytest.fixture(scope="function")
def client(db: Session) -> Generator[TestClient, None, None]:
    def override_get_db():
        yield db
    
    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
```

### 10. ミドルウェアの型付け
```python
# app/middleware/logging.py
from typing import Callable, Any
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.types import ASGIApp
import time
import logging

logger = logging.getLogger(__name__)

class LoggingMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: ASGIApp):
        super().__init__(app)
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.time()
        
        # リクエストログ
        logger.info(f"Request: {request.method} {request.url.path}")
        
        response = await call_next(request)
        
        # レスポンスログ
        process_time = time.time() - start_time
        logger.info(
            f"Response: {response.status_code} "
            f"Process time: {process_time:.3f}s"
        )
        
        response.headers["X-Process-Time"] = str(process_time)
        return response
```

### 11. キャッシュ層の型付け
```python
# app/cache.py
from typing import Optional, Any, Union, Type, TypeVar
from datetime import timedelta
import json
import redis
from pydantic import BaseModel

T = TypeVar('T', bound=BaseModel)

class CacheService:
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
    
    async def get(
        self,
        key: str,
        model: Type[T]
    ) -> Optional[T]:
        data = self.redis.get(key)
        if data:
            return model.model_validate_json(data)
        return None
    
    async def set(
        self,
        key: str,
        value: BaseModel,
        expire: Optional[Union[int, timedelta]] = None
    ) -> None:
        data = value.model_dump_json()
        if expire:
            if isinstance(expire, timedelta):
                expire = int(expire.total_seconds())
            self.redis.setex(key, expire, data)
        else:
            self.redis.set(key, data)
    
    async def delete(self, key: str) -> None:
        self.redis.delete(key)
```

### 12. バックグラウンドタスクの型付け
```python
# app/background/tasks.py
from typing import Dict, Any, Optional
from celery import Celery
from app.core.config import settings
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

celery_app = Celery(
    "tasks",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND
)

@celery_app.task(bind=True, max_retries=3)
def send_email_task(
    self,
    to_email: str,
    subject: str,
    body: str,
    html_body: Optional[str] = None
) -> Dict[str, Any]:
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From'] = settings.SMTP_FROM
        msg['To'] = to_email
        
        # テキストパート
        text_part = MIMEText(body, 'plain')
        msg.attach(text_part)
        
        # HTMLパート（オプション）
        if html_body:
            html_part = MIMEText(html_body, 'html')
            msg.attach(html_part)
        
        # メール送信
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
            server.starttls()
            server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
            server.send_message(msg)
        
        return {"status": "success", "message": "Email sent successfully"}
    
    except Exception as exc:
        self.retry(exc=exc, countdown=60)
```

## 優先度: 低

### 13. OpenAPI拡張
```python
# app/openapi.py
from typing import Dict, Any, List
from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

def custom_openapi(app: FastAPI) -> Dict[str, Any]:
    if app.openapi_schema:
        return app.openapi_schema
    
    openapi_schema = get_openapi(
        title="ITDO ERP API",
        version="2.0.0",
        description="Complete ERP System API",
        routes=app.routes,
    )
    
    # セキュリティスキーマの追加
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
        }
    }
    
    # レスポンスの共通定義
    openapi_schema["components"]["responses"] = {
        "UnauthorizedError": {
            "description": "Authentication information is missing or invalid",
            "content": {
                "application/json": {
                    "schema": {
                        "type": "object",
                        "properties": {
                            "detail": {"type": "string"}
                        }
                    }
                }
            }
        }
    }
    
    app.openapi_schema = openapi_schema
    return app.openapi_schema
```

### 14. 監査ログの型付け
```python
# app/audit.py
from typing import Optional, Dict, Any
from datetime import datetime
from sqlalchemy.orm import Session
from app.models.audit import AuditLog
from app.models.user import User
import json

class AuditLogger:
    def __init__(self, db: Session):
        self.db = db
    
    async def log(
        self,
        user: User,
        action: str,
        resource_type: str,
        resource_id: str,
        changes: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ) -> AuditLog:
        audit_log = AuditLog(
            user_id=user.id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            changes=json.dumps(changes) if changes else None,
            ip_address=ip_address,
            user_agent=user_agent,
            created_at=datetime.utcnow()
        )
        
        self.db.add(audit_log)
        self.db.commit()
        self.db.refresh(audit_log)
        
        return audit_log
```

### 15. パフォーマンスプロファイリング
```python
# app/profiling.py
from typing import Callable, Any
import time
import functools
from app.core.logging import logger

def profile_performance(func: Callable) -> Callable:
    @functools.wraps(func)
    async def wrapper(*args: Any, **kwargs: Any) -> Any:
        start_time = time.perf_counter()
        
        try:
            result = await func(*args, **kwargs)
            
            end_time = time.perf_counter()
            execution_time = end_time - start_time
            
            logger.info(
                f"Function {func.__name__} took {execution_time:.4f} seconds",
                extra={
                    "function": func.__name__,
                    "execution_time": execution_time,
                    "args": str(args)[:100],
                    "kwargs": str(kwargs)[:100]
                }
            )
            
            return result
            
        except Exception as e:
            end_time = time.perf_counter()
            execution_time = end_time - start_time
            
            logger.error(
                f"Function {func.__name__} failed after {execution_time:.4f} seconds",
                extra={
                    "function": func.__name__,
                    "execution_time": execution_time,
                    "error": str(e)
                }
            )
            
            raise
    
    return wrapper
```

## 実行順序
1. MyPy完全対応スクリプト実行（最優先）
2. Pydanticモデルの型付け
3. SQLAlchemyモデルの型付け
4. APIエンドポイントの型付け
5. サービス層の型安全性
6-15. 順次実装

各タスクの完了後、自動的に次のタスクに移行してください。