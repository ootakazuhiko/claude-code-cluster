"""Main CLI application for Claude Code Cluster PoC"""

import sys
import typer
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeElapsedColumn
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from typing import Optional

from src.core.config import get_settings
from src.services.agent import ClaudeAgent
from src.utils.logging import setup_logging, get_logger
from src.core.exceptions import ClaudeClusterError


# Initialize Typer app
app = typer.Typer(
    name="claude-cluster",
    help="Claude Code Cluster PoC - Automated GitHub Issue to Pull Request",
    add_completion=False
)

# Initialize console
console = Console()
logger = get_logger(__name__)


def setup_environment():
    """Setup environment and logging"""
    settings = get_settings()
    setup_logging(settings.logs_path, settings.log_level)
    return settings


@app.command()
def setup():
    """Initialize the Claude Code Cluster PoC"""
    
    console.print(Panel.fit(
        "[bold blue]Claude Code Cluster PoC Setup[/bold blue]",
        style="blue"
    ))
    
    try:
        settings = setup_environment()
        
        # Initialize agent to verify setup
        agent = ClaudeAgent(settings)
        
        # Get system status
        status = agent.get_system_status()
        
        # Display setup information
        console.print(f"[green]✓[/green] Workspace: {settings.workspace_path}")
        console.print(f"[green]✓[/green] Data path: {settings.data_path}")
        console.print(f"[green]✓[/green] Logs path: {settings.logs_path}")
        console.print(f"[green]✓[/green] Git available: {status['git_available']}")
        
        # Check API connections
        if "error" not in status["github_rate_limit"]:
            console.print("[green]✓[/green] GitHub API: Connected")
        else:
            console.print("[red]✗[/red] GitHub API: Error")
        
        console.print("[green]✓[/green] Claude API: Connected")
        
        console.print("\n[bold green]Setup completed successfully![/bold green]")
        console.print("\n[dim]Next steps:[/dim]")
        console.print("1. Create a task: [bold]claude-cluster create-task --issue 123 --repo owner/repo[/bold]")
        console.print("2. Run the task: [bold]claude-cluster run-task --task-id <task-id>[/bold]")
        
    except Exception as e:
        console.print(f"[red]Setup failed: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def create_task(
    issue: int = typer.Option(..., "--issue", "-i", help="GitHub issue number"),
    repo: str = typer.Option(..., "--repo", "-r", help="Repository name (owner/repo)"),
):
    """Create a task from GitHub issue"""
    
    console.print(f"[bold]Creating task from issue #{issue} in {repo}[/bold]")
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
            transient=True
        ) as progress:
            
            task_progress = progress.add_task("Fetching issue data...", total=None)
            
            # Create task
            task_id = agent.create_task_from_issue(issue, repo)
            
            progress.update(task_progress, description=f"✓ Task created: {task_id}")
        
        # Display task information
        task = agent.get_task_status(task_id)
        
        table = Table(title="Task Created")
        table.add_column("Field", style="cyan")
        table.add_column("Value", style="white")
        
        table.add_row("Task ID", task_id)
        table.add_row("Issue", f"#{task['issue']['number']}")
        table.add_row("Title", task['issue']['title'])
        table.add_row("Repository", task['issue']['repository'])
        table.add_row("Status", task['status'])
        table.add_row("Priority", task['analysis']['priority'])
        table.add_row("Type", task['analysis']['type'])
        table.add_row("Requirements", ", ".join(task['analysis']['requirements']))
        table.add_row("Estimated Duration", f"{task['analysis']['estimated_duration_minutes']} minutes")
        
        console.print(table)
        
        console.print(f"\n[green]Task {task_id} created successfully![/green]")
        console.print(f"[dim]Run with: [bold]claude-cluster run-task --task-id {task_id}[/bold][/dim]")
        
    except ClaudeClusterError as e:
        console.print(f"[red]Failed to create task: {e}[/red]")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"[red]Unexpected error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def run_task(
    task_id: str = typer.Option(..., "--task-id", "-t", help="Task ID to execute"),
):
    """Execute a task"""
    
    console.print(f"[bold]Executing task {task_id}[/bold]")
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        # Check task exists
        task = agent.get_task_status(task_id)
        if not task:
            console.print(f"[red]Task {task_id} not found[/red]")
            raise typer.Exit(1)
        
        # Display task info
        console.print(f"Issue: #{task['issue']['number']} - {task['issue']['title']}")
        console.print(f"Repository: {task['issue']['repository']}")
        
        # Execute task with progress
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TextColumn("[progress.percentage]{task.percentage:>3.0f}%"),
            TimeElapsedColumn(),
            console=console
        ) as progress:
            
            task_progress = progress.add_task("Executing task...", total=9)
            
            # Update progress during execution
            progress.update(task_progress, advance=1, description="Cloning repository...")
            
            # Execute task
            result = agent.run_task(task_id)
            
            progress.update(task_progress, completed=9, description="✓ Task completed")
        
        # Display results
        console.print(f"\n[green]Task {task_id} completed successfully![/green]")
        
        # Show results table
        table = Table(title="Execution Results")
        table.add_column("Field", style="cyan")
        table.add_column("Value", style="white")
        
        table.add_row("Status", result['status'])
        table.add_row("Files Modified", str(len(result['applied_files'])))
        table.add_row("Branch", result['branch_name'])
        table.add_row("Pull Request", result['pr_info']['html_url'])
        table.add_row("PR Number", f"#{result['pr_info']['number']}")
        
        console.print(table)
        
        # Show implementation summary
        impl = result['implementation']
        console.print(f"\n[bold]Implementation Summary:[/bold]")
        console.print(f"{impl.get('summary', 'No summary available')}")
        
        if impl.get('notes'):
            console.print(f"\n[bold]Notes:[/bold]")
            console.print(f"{impl['notes']}")
        
    except ClaudeClusterError as e:
        console.print(f"[red]Task execution failed: {e}[/red]")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"[red]Unexpected error: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def status(
    task_id: Optional[str] = typer.Option(None, "--task-id", "-t", help="Specific task ID to check")
):
    """Show task status"""
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        if task_id:
            # Show specific task status
            task = agent.get_task_status(task_id)
            
            if not task:
                console.print(f"[red]Task {task_id} not found[/red]")
                raise typer.Exit(1)
            
            # Display detailed task information
            console.print(f"[bold]Task {task_id} Status[/bold]")
            
            table = Table()
            table.add_column("Field", style="cyan")
            table.add_column("Value", style="white")
            
            table.add_row("Status", task['status'])
            table.add_row("Issue", f"#{task['issue']['number']}")
            table.add_row("Title", task['issue']['title'])
            table.add_row("Repository", task['issue']['repository'])
            table.add_row("Created", task['created_at'])
            table.add_row("Updated", task['updated_at'])
            
            if task['execution']['started_at']:
                table.add_row("Started", task['execution']['started_at'])
            
            if task['execution']['completed_at']:
                table.add_row("Completed", task['execution']['completed_at'])
                table.add_row("Duration", f"{task['execution']['duration_seconds']:.1f}s")
            
            if task['results']['pr_url']:
                table.add_row("Pull Request", task['results']['pr_url'])
            
            console.print(table)
            
        else:
            # Show all tasks summary
            tasks = agent.get_task_status()
            system_status = agent.get_system_status()
            
            # System status
            console.print("[bold]System Status[/bold]")
            console.print(f"Total tasks: {system_status['tasks']['total_tasks']}")
            
            # Status counts
            status_counts = system_status['tasks']['status_counts']
            for status, count in status_counts.items():
                color = {
                    "created": "blue",
                    "running": "yellow", 
                    "completed": "green",
                    "failed": "red",
                    "cancelled": "dim"
                }.get(status, "white")
                
                console.print(f"  {status}: [{color}]{count}[/{color}]")
            
            # Recent tasks
            if tasks:
                console.print(f"\n[bold]Recent Tasks[/bold]")
                
                table = Table()
                table.add_column("Task ID", style="cyan")
                table.add_column("Issue", style="white")
                table.add_column("Status", style="white")
                table.add_column("Created", style="dim")
                
                for task in tasks[:10]:  # Show last 10 tasks
                    status_color = {
                        "created": "blue",
                        "running": "yellow",
                        "completed": "green", 
                        "failed": "red",
                        "cancelled": "dim"
                    }.get(task['status'], "white")
                    
                    table.add_row(
                        task['id'],
                        f"#{task['issue']['number']}",
                        f"[{status_color}]{task['status']}[/{status_color}]",
                        task['created_at'][:16]  # Show date and time only
                    )
                
                console.print(table)
            else:
                console.print("\n[dim]No tasks found[/dim]")
        
    except Exception as e:
        console.print(f"[red]Error getting status: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def cancel(
    task_id: str = typer.Option(..., "--task-id", "-t", help="Task ID to cancel")
):
    """Cancel a running task"""
    
    console.print(f"[bold]Cancelling task {task_id}[/bold]")
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        success = agent.cancel_task(task_id)
        
        if success:
            console.print(f"[green]Task {task_id} cancelled successfully[/green]")
        else:
            console.print(f"[yellow]Task {task_id} could not be cancelled (not running?)[/yellow]")
        
    except Exception as e:
        console.print(f"[red]Error cancelling task: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def cleanup(
    days: int = typer.Option(30, "--days", "-d", help="Days to keep completed tasks")
):
    """Clean up old completed tasks"""
    
    console.print(f"[bold]Cleaning up tasks older than {days} days[/bold]")
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        removed_count = agent.cleanup_old_tasks(days)
        
        console.print(f"[green]Cleaned up {removed_count} old tasks[/green]")
        
    except Exception as e:
        console.print(f"[red]Error during cleanup: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def export_tasks(
    output: str = typer.Option("tasks_export.json", "--output", "-o", help="Output file path")
):
    """Export tasks to JSON file"""
    
    console.print(f"[bold]Exporting tasks to {output}[/bold]")
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        agent.export_tasks(output)
        
        console.print(f"[green]Tasks exported to {output}[/green]")
        
    except Exception as e:
        console.print(f"[red]Error exporting tasks: {e}[/red]")
        raise typer.Exit(1)


@app.command()
def system_info():
    """Show system information"""
    
    console.print("[bold]System Information[/bold]")
    
    try:
        settings = setup_environment()
        agent = ClaudeAgent(settings)
        
        status = agent.get_system_status()
        
        # Settings info
        console.print(f"\n[cyan]Configuration:[/cyan]")
        console.print(f"  Workspace: {status['workspace_path']}")
        console.print(f"  Data path: {status['data_path']}")
        console.print(f"  Log level: {settings.log_level}")
        
        # Git info
        console.print(f"\n[cyan]Git:[/cyan]")
        console.print(f"  Available: {status['git_available']}")
        console.print(f"  User: {settings.git_user_name} <{settings.git_user_email}>")
        
        # GitHub API info
        console.print(f"\n[cyan]GitHub API:[/cyan]")
        if "error" not in status["github_rate_limit"]:
            rate_limit = status["github_rate_limit"]["core"]
            console.print(f"  Rate limit: {rate_limit['remaining']}/{rate_limit['limit']}")
            console.print(f"  Reset: {rate_limit['reset']}")
        else:
            console.print(f"  Error: {status['github_rate_limit']['error']}")
        
        # Claude API info
        console.print(f"\n[cyan]Claude API:[/cyan]")
        claude_info = status["claude_usage"]
        console.print(f"  Model: {claude_info['model']}")
        console.print(f"  Status: {claude_info['status']}")
        
        # Tasks summary
        console.print(f"\n[cyan]Tasks:[/cyan]")
        tasks_info = status["tasks"]
        console.print(f"  Total: {tasks_info['total_tasks']}")
        for status_name, count in tasks_info['status_counts'].items():
            console.print(f"  {status_name}: {count}")
        
    except Exception as e:
        console.print(f"[red]Error getting system info: {e}[/red]")
        raise typer.Exit(1)


if __name__ == "__main__":
    app()