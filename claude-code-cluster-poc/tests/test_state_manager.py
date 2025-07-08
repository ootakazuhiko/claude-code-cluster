"""Tests for State Manager"""

import pytest
import json
from pathlib import Path
from unittest.mock import Mock, patch
from src.services.state_manager import StateManager
from src.core.exceptions import TaskNotFoundError


class TestStateManager:
    """Test State Manager functionality"""
    
    @patch('src.services.state_manager.get_settings')
    def test_init(self, mock_get_settings):
        """Test StateManager initialization"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        with patch('src.services.state_manager.save_json') as mock_save:
            with patch('pathlib.Path.exists', return_value=False):
                manager = StateManager()
                
                assert manager.settings == mock_settings
                # Should create tasks.json and config.json
                assert mock_save.call_count == 2
    
    @patch('src.services.state_manager.get_settings')
    def test_create_task(self, mock_get_settings):
        """Test task creation"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        issue_data = {
            "number": 1,
            "title": "Test Issue",
            "body": "Test body",
            "labels": ["bug"],
            "html_url": "https://github.com/test/repo/issues/1",
            "repository": {
                "full_name": "test/repo"
            }
        }
        
        analysis = {
            "priority": "medium",
            "type": "bug",
            "requirements": ["backend"],
            "complexity": "low"
        }
        
        with patch('src.services.state_manager.load_json', return_value=None):
            with patch('src.services.state_manager.save_json') as mock_save:
                with patch('pathlib.Path.exists', return_value=True):
                    with patch('src.utils.helpers.generate_task_id', return_value="test-task-123"):
                        manager = StateManager()
                        task_id = manager.create_task(issue_data, analysis)
                        
                        assert task_id == "test-task-123"
                        # Should save the task
                        mock_save.assert_called()
    
    @patch('src.services.state_manager.get_settings')
    def test_get_task_success(self, mock_get_settings):
        """Test successful task retrieval"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        tasks_data = {
            "tasks": {
                "test-task-123": {
                    "id": "test-task-123",
                    "status": "created",
                    "issue": {"number": 1}
                }
            }
        }
        
        with patch('src.services.state_manager.load_json', return_value=tasks_data):
            with patch('pathlib.Path.exists', return_value=True):
                manager = StateManager()
                task = manager.get_task("test-task-123")
                
                assert task["id"] == "test-task-123"
                assert task["status"] == "created"
    
    @patch('src.services.state_manager.get_settings')
    def test_get_task_not_found(self, mock_get_settings):
        """Test task not found error"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        with patch('src.services.state_manager.load_json', return_value={"tasks": {}}):
            with patch('pathlib.Path.exists', return_value=True):
                manager = StateManager()
                
                with pytest.raises(TaskNotFoundError):
                    manager.get_task("nonexistent-task")
    
    @patch('src.services.state_manager.get_settings')
    def test_update_task_status(self, mock_get_settings):
        """Test task status update"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        tasks_data = {
            "tasks": {
                "test-task-123": {
                    "id": "test-task-123",
                    "status": "created",
                    "execution": {"started_at": None, "completed_at": None}
                }
            }
        }
        
        with patch('src.services.state_manager.load_json', return_value=tasks_data):
            with patch('src.services.state_manager.save_json') as mock_save:
                with patch('pathlib.Path.exists', return_value=True):
                    manager = StateManager()
                    manager.update_task_status("test-task-123", "running")
                    
                    # Should save updated task
                    mock_save.assert_called()
    
    @patch('src.services.state_manager.get_settings')
    def test_list_tasks(self, mock_get_settings):
        """Test listing tasks"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        tasks_data = {
            "tasks": {
                "task-1": {"id": "task-1", "status": "completed", "created_at": "2023-01-01"},
                "task-2": {"id": "task-2", "status": "running", "created_at": "2023-01-02"}
            }
        }
        
        with patch('src.services.state_manager.load_json', return_value=tasks_data):
            with patch('pathlib.Path.exists', return_value=True):
                manager = StateManager()
                
                # List all tasks
                all_tasks = manager.list_tasks()
                assert len(all_tasks) == 2
                
                # List by status
                running_tasks = manager.list_tasks(status="running")
                assert len(running_tasks) == 1
                assert running_tasks[0]["id"] == "task-2"
    
    @patch('src.services.state_manager.get_settings')
    def test_get_task_summary(self, mock_get_settings):
        """Test task summary"""
        mock_settings = Mock()
        mock_settings.data_path = Path("/tmp/test_data")
        mock_get_settings.return_value = mock_settings
        
        tasks_data = {
            "tasks": {
                "task-1": {"id": "task-1", "status": "completed", "created_at": "2023-01-01"},
                "task-2": {"id": "task-2", "status": "running", "created_at": "2023-01-02"},
                "task-3": {"id": "task-3", "status": "failed", "created_at": "2023-01-03"}
            }
        }
        
        with patch('src.services.state_manager.load_json', return_value=tasks_data):
            with patch('pathlib.Path.exists', return_value=True):
                manager = StateManager()
                summary = manager.get_task_summary()
                
                assert summary["total_tasks"] == 3
                assert summary["status_counts"]["completed"] == 1
                assert summary["status_counts"]["running"] == 1
                assert summary["status_counts"]["failed"] == 1
                assert len(summary["recent_tasks"]) == 3