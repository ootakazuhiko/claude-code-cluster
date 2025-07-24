#!/usr/bin/env python3
"""
Optimized GitHub Worker with Smart Polling
Implements adaptive polling intervals and rate limit management
"""

import os
import time
import json
import random
import logging
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional, Dict, List, Tuple

from github import Github, Auth, RateLimitExceededException
from github.Issue import Issue

# Configuration
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_REPO = os.getenv("GITHUB_REPO", "ootakazuhiko/claude-code-cluster")
WORKER_NAME = os.getenv("WORKER_NAME", "CC01")
WORKER_LABEL = os.getenv("WORKER_LABEL", "cc01")

# Polling configuration
BASE_INTERVAL = 180  # 3 minutes
MIN_INTERVAL = 60    # 1 minute
MAX_INTERVAL = 900   # 15 minutes
NIGHT_INTERVAL = 900 # 15 minutes for night time

# Rate limit safety
MAX_REQUESTS_PER_HOUR = 1500  # Conservative limit per worker

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(f"Worker-{WORKER_NAME}")


class WorkerMetrics:
    """Track worker performance metrics"""
    
    def __init__(self):
        self.polls_this_hour = 0
        self.tasks_found_this_hour = 0
        self.hour_start = datetime.now()
        self.total_polls = 0
        self.total_tasks = 0
        self.start_time = datetime.now()
        
    def record_poll(self, tasks_found: int):
        """Record a polling event"""
        now = datetime.now()
        
        # Reset hourly counters if needed
        if (now - self.hour_start).seconds > 3600:
            self.polls_this_hour = 0
            self.tasks_found_this_hour = 0
            self.hour_start = now
        
        self.polls_this_hour += 1
        self.tasks_found_this_hour += tasks_found
        self.total_polls += 1
        self.total_tasks += tasks_found
        
    def get_hourly_rate(self) -> int:
        """Get current hourly polling rate"""
        return self.polls_this_hour
    
    def log_metrics(self):
        """Log current metrics"""
        runtime = (datetime.now() - self.start_time).seconds / 3600
        avg_polls_per_hour = self.total_polls / max(runtime, 1)
        avg_tasks_per_hour = self.total_tasks / max(runtime, 1)
        
        logger.info(f"Metrics - Polls/hr: {avg_polls_per_hour:.1f}, "
                   f"Tasks/hr: {avg_tasks_per_hour:.1f}, "
                   f"Current hr: {self.polls_this_hour} polls")


class SmartPoller:
    """Intelligent polling interval calculator"""
    
    def __init__(self):
        self.last_activity = None
        self.consecutive_empty_polls = 0
        self.activity_score = 0
        
    def calculate_interval(self, found_tasks: int, metrics: WorkerMetrics) -> int:
        """Calculate next polling interval based on activity and time"""
        now = datetime.now()
        hour = now.hour
        
        # Update activity tracking
        if found_tasks > 0:
            self.last_activity = now
            self.consecutive_empty_polls = 0
            self.activity_score = min(10, self.activity_score + 2)
        else:
            self.consecutive_empty_polls += 1
            self.activity_score = max(0, self.activity_score - 1)
        
        # Check rate limits
        if metrics.get_hourly_rate() >= MAX_REQUESTS_PER_HOUR - 100:
            logger.warning("Approaching rate limit, increasing interval")
            return MAX_INTERVAL
        
        # Night time (0-6 AM)
        if 0 <= hour < 6:
            return NIGHT_INTERVAL
        
        # Recent activity boost
        if self.last_activity:
            minutes_since_activity = (now - self.last_activity).seconds / 60
            if minutes_since_activity < 5:
                return MIN_INTERVAL
            elif minutes_since_activity < 15:
                return BASE_INTERVAL // 2
        
        # High activity score
        if self.activity_score >= 8:
            return MIN_INTERVAL
        elif self.activity_score >= 5:
            return BASE_INTERVAL // 2
        
        # Many empty polls
        if self.consecutive_empty_polls > 10:
            return MAX_INTERVAL
        elif self.consecutive_empty_polls > 5:
            return BASE_INTERVAL * 2
        
        # Business hours (9-18)
        if 9 <= hour < 18:
            return BASE_INTERVAL
        
        # Default
        return BASE_INTERVAL


class ExponentialBackoff:
    """Handle retry delays with exponential backoff"""
    
    def __init__(self):
        self.failure_count = 0
        self.base_delay = 60
        self.max_delay = 3600
        
    def get_delay(self) -> float:
        """Get next delay with jitter"""
        delay = min(
            self.base_delay * (2 ** self.failure_count),
            self.max_delay
        )
        # Add 10% jitter to prevent thundering herd
        jitter = random.uniform(0, delay * 0.1)
        return delay + jitter
    
    def record_success(self):
        """Reset on success"""
        self.failure_count = 0
        
    def record_failure(self):
        """Increment failure count"""
        self.failure_count += 1


class OptimizedGitHubWorker:
    """GitHub worker with optimized polling and rate limit handling"""
    
    def __init__(self):
        if not GITHUB_TOKEN:
            raise ValueError("GITHUB_TOKEN environment variable required")
            
        self.github = Github(auth=Auth.Token(GITHUB_TOKEN))
        self.repo = self.github.get_repo(GITHUB_REPO)
        self.user = self.github.get_user()
        
        self.state_file = Path(f"~/.claude/state/worker-{WORKER_NAME.lower()}.json").expanduser()
        self.state = self._load_state()
        
        self.poller = SmartPoller()
        self.backoff = ExponentialBackoff()
        self.metrics = WorkerMetrics()
        
        # ETag cache for conditional requests
        self.etag_cache = {}
        
    def _load_state(self) -> Dict:
        """Load persistent state"""
        if self.state_file.exists():
            with open(self.state_file, 'r') as f:
                return json.load(f)
        return {
            "last_poll": None,
            "processed_issues": [],
            "in_progress": []
        }
    
    def _save_state(self):
        """Save persistent state"""
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, 'w') as f:
            json.dump(self.state, f, indent=2)
    
    def check_rate_limit(self) -> Tuple[int, int]:
        """Check GitHub API rate limit"""
        try:
            rate_limit = self.github.get_rate_limit()
            core = rate_limit.core
            
            logger.info(f"Rate limit: {core.remaining}/{core.limit}, "
                       f"Reset: {core.reset.strftime('%H:%M:%S')}")
            
            return core.remaining, core.limit
            
        except Exception as e:
            logger.error(f"Failed to check rate limit: {e}")
            return 0, 0
    
    def find_new_tasks(self) -> List[Issue]:
        """Find new tasks with conditional requests"""
        logger.info(f"Polling for tasks with label '{WORKER_LABEL}'")
        
        try:
            # Use conditional request if we have an ETag
            headers = {}
            cache_key = f"issues_{WORKER_LABEL}"
            
            # Note: PyGithub doesn't directly support ETags, 
            # so we'll use regular polling but track changes
            issues = self.repo.get_issues(
                labels=[WORKER_LABEL],
                state='open'
            )
            
            new_tasks = []
            
            for issue in issues:
                # Skip processed or in-progress
                if (issue.number in self.state["processed_issues"] or 
                    issue.number in self.state["in_progress"]):
                    continue
                
                # Skip if assigned to someone else
                if issue.assignee and issue.assignee.login != self.user.login:
                    continue
                
                # Skip PRs
                if issue.pull_request:
                    continue
                
                # Check for completion labels
                labels = [label.name for label in issue.labels]
                if "in-progress" not in labels and "completed" not in labels:
                    new_tasks.append(issue)
                    logger.info(f"Found new task: Issue #{issue.number}")
            
            return new_tasks
            
        except RateLimitExceededException:
            logger.error("Rate limit exceeded!")
            raise
        except Exception as e:
            logger.error(f"Error finding tasks: {e}")
            return []
    
    def claim_task(self, issue: Issue) -> bool:
        """Claim a task"""
        try:
            logger.info(f"Claiming issue #{issue.number}")
            
            # Assign to self
            issue.add_to_assignees(self.user)
            
            # Add in-progress label
            issue.add_to_labels("in-progress")
            
            # Add claim comment
            issue.create_comment(f"""
## Task Claimed by {WORKER_NAME}

Starting work on this issue.

- **Worker**: {WORKER_NAME}  
- **Started**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **Estimated Duration**: 2-4 hours

Progress updates will follow.
            """)
            
            # Update state
            self.state["in_progress"].append(issue.number)
            self._save_state()
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to claim issue #{issue.number}: {e}")
            return False
    
    def process_task(self, issue: Issue):
        """Process task (override in subclasses)"""
        logger.info(f"Processing issue #{issue.number}")
        
        # Simulate work
        time.sleep(10)
        
        # Mark complete
        try:
            issue.remove_from_labels("in-progress")
            issue.add_to_labels("completed", "ready-for-review")
            
            issue.create_comment(f"""
## Task Completed ✅

Task has been completed successfully.

- **Worker**: {WORKER_NAME}
- **Completed**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
- **PR**: #{issue.number + 1000} (simulated)

Ready for review!
            """)
            
            # Update state
            self.state["in_progress"].remove(issue.number)
            self.state["processed_issues"].append(issue.number)
            self._save_state()
            
        except Exception as e:
            logger.error(f"Failed to complete task: {e}")
    
    def get_worker_offset(self) -> int:
        """Get timing offset to distribute load"""
        offsets = {
            "CC01": 0,
            "CC02": 20,
            "CC03": 40,
        }
        return offsets.get(WORKER_NAME, random.randint(0, 60))
    
    def run(self):
        """Main polling loop with optimizations"""
        logger.info(f"Starting optimized {WORKER_NAME} worker")
        logger.info(f"Repository: {GITHUB_REPO}")
        logger.info(f"Label: {WORKER_LABEL}")
        
        # Initial offset to distribute load
        offset = self.get_worker_offset()
        if offset > 0:
            logger.info(f"Waiting {offset}s for load distribution")
            time.sleep(offset)
        
        # Check initial rate limit
        remaining, limit = self.check_rate_limit()
        if remaining < 100:
            logger.warning(f"Low rate limit on start: {remaining}")
        
        while True:
            try:
                # Check if we should continue
                remaining, _ = self.check_rate_limit()
                if remaining < 50:
                    wait_time = 3600  # 1 hour
                    logger.warning(f"Rate limit too low ({remaining}), waiting {wait_time}s")
                    time.sleep(wait_time)
                    continue
                
                # Poll for tasks
                tasks = self.find_new_tasks()
                self.metrics.record_poll(len(tasks))
                
                # Process any new tasks
                for task in tasks:
                    if self.claim_task(task):
                        self.process_task(task)
                        self.backoff.record_success()
                
                # Calculate next interval
                interval = self.poller.calculate_interval(len(tasks), self.metrics)
                
                # Log metrics periodically
                if self.metrics.total_polls % 20 == 0:
                    self.metrics.log_metrics()
                
                # Update state
                self.state["last_poll"] = datetime.now().isoformat()
                self._save_state()
                
                logger.info(f"Next poll in {interval}s (found {len(tasks)} tasks)")
                time.sleep(interval)
                
            except RateLimitExceededException:
                logger.error("Rate limit exceeded!")
                wait_time = 3600
                logger.info(f"Waiting {wait_time}s for rate limit reset")
                time.sleep(wait_time)
                
            except KeyboardInterrupt:
                logger.info("Shutdown requested")
                break
                
            except Exception as e:
                logger.error(f"Error in polling loop: {e}")
                self.backoff.record_failure()
                delay = self.backoff.get_delay()
                logger.info(f"Backing off for {delay:.0f}s")
                time.sleep(delay)
        
        logger.info("Worker stopped")


def main():
    """Main entry point"""
    worker = OptimizedGitHubWorker()
    worker.run()


if __name__ == "__main__":
    main()