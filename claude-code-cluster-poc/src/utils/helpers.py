"""Helper functions"""

import json
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


def generate_task_id() -> str:
    """Generate unique task ID"""
    return f"task-{uuid.uuid4().hex[:8]}"


def current_timestamp() -> str:
    """Get current timestamp as ISO string"""
    return datetime.now().isoformat()


def save_json(data: Any, file_path: Path) -> None:
    """Save data to JSON file"""
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def load_json(file_path: Path) -> Any:
    """Load data from JSON file"""
    if not file_path.exists():
        return None
    
    with open(file_path, "r", encoding="utf-8") as f:
        return json.load(f)


def ensure_directory(path: Path) -> None:
    """Ensure directory exists"""
    path.mkdir(parents=True, exist_ok=True)


def sanitize_filename(name: str) -> str:
    """Sanitize filename by removing invalid characters"""
    import re
    # Remove invalid characters for filename
    sanitized = re.sub(r'[<>:"/\\|?*]', '-', name)
    # Remove extra spaces and dots
    sanitized = re.sub(r'\s+', '-', sanitized.strip())
    return sanitized[:100]  # Limit length


def parse_repo_url(repo: str) -> Dict[str, str]:
    """Parse repository string into owner and repo name"""
    if "/" not in repo:
        raise ValueError("Repository must be in format 'owner/repo'")
    
    parts = repo.split("/")
    if len(parts) != 2:
        raise ValueError("Repository must be in format 'owner/repo'")
    
    return {"owner": parts[0], "repo": parts[1]}


def extract_keywords_from_text(text: str) -> List[str]:
    """Extract keywords from text for analysis"""
    import re
    
    # Simple keyword extraction
    # Remove special characters and split by whitespace
    clean_text = re.sub(r'[^\w\s]', ' ', text.lower())
    words = clean_text.split()
    
    # Filter out common words and short words
    stop_words = {
        'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 
        'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
        'before', 'after', 'above', 'below', 'between', 'among', 'this', 'that',
        'these', 'those', 'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 
        'ourselves', 'you', 'your', 'yours', 'yourself', 'yourselves', 'he', 
        'him', 'his', 'himself', 'she', 'her', 'hers', 'herself', 'it', 'its',
        'itself', 'they', 'them', 'their', 'theirs', 'themselves', 'what', 
        'which', 'who', 'whom', 'this', 'that', 'these', 'those', 'am', 'is',
        'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had',
        'having', 'do', 'does', 'did', 'doing', 'will', 'would', 'should',
        'could', 'can', 'may', 'might', 'must', 'shall'
    }
    
    keywords = [word for word in words if len(word) > 2 and word not in stop_words]
    
    # Return unique keywords
    return list(set(keywords))