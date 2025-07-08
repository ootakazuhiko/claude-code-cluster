"""Configuration management"""

from pathlib import Path
from typing import Optional
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """アプリケーション設定"""
    
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    
    # API設定
    github_token: str = Field(..., description="GitHub API token")
    anthropic_api_key: str = Field(..., description="Anthropic API key")
    
    # Git設定
    git_user_name: str = Field(default="Claude Code Bot", description="Git user name")
    git_user_email: str = Field(default="claude@example.com", description="Git user email")
    
    # パス設定
    workspace_path: Path = Field(default=Path("./workspace"), description="Workspace directory")
    data_path: Path = Field(default=Path("./data"), description="Data directory")
    logs_path: Path = Field(default=Path("./logs"), description="Logs directory")
    
    # アプリケーション設定
    default_branch: str = Field(default="main", description="Default git branch")
    log_level: str = Field(default="INFO", description="Log level")
    
    def model_post_init(self, __context) -> None:
        """Post-initialization: create directories"""
        self.workspace_path.mkdir(exist_ok=True, parents=True)
        self.data_path.mkdir(exist_ok=True, parents=True)
        self.logs_path.mkdir(exist_ok=True, parents=True)


# Global settings instance
_settings: Optional[Settings] = None


def get_settings() -> Settings:
    """Get settings instance (singleton)"""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings