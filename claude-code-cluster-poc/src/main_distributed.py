"""Main CLI for distributed Claude Code Cluster PoC"""

import asyncio
import logging
import typer
from typing import Optional, List
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.progress import Progress, SpinnerColumn, TextColumn
from pathlib import Path

from src.core.config import get_settings, setup_environment
from src.services.distributed_agent import DistributedAgent
from src.services.coordinator_api import CoordinatorAPI
from src.services.agent_node import DistributedAgentNode
from src.utils.logging import get_logger, setup_logging


# Initialize components
console = Console()
app = typer.Typer(
    name="claude-code-cluster-distributed",
    help="Distributed Claude Code Cluster PoC with specialized agents",
    rich_markup_mode="rich"
)
logger = get_logger(__name__)


@app.command()
def setup():
    """Setup the distributed cluster environment"""
    try:
        console.print(Panel("🚀 Setting up Claude Code Cluster (Distributed)", style="bold blue"))
        
        settings = setup_environment()
        
        console.print("✅ Environment configured")
        console.print(f"✅ GitHub token configured: {settings.github_token[:8]}...")
        console.print(f"✅ Anthropic API key configured: {settings.anthropic_api_key[:8]}...")
        console.print("✅ Distributed mode enabled")
        
        console.print(Panel("Setup completed! You can now run distributed tasks.", style="bold green"))
        
    except Exception as e:
        console.print(f"❌ Setup failed: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def start_coordinator(
    port: int = typer.Option(8001, help="Port for coordinator API"),
    host: str = typer.Option("0.0.0.0", help="Host for coordinator API")
):
    """Start the cluster coordinator"""
    try:
        console.print(Panel(f"🎯 Starting Cluster Coordinator on {host}:{port}", style="bold blue"))
        
        coordinator = CoordinatorAPI(port)
        coordinator.run(host=host)
        
    except Exception as e:
        console.print(f"❌ Failed to start coordinator: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def start_node(
    coordinator_host: str = typer.Option("localhost", help="Coordinator host"),
    coordinator_port: int = typer.Option(8001, help="Coordinator port"),
    agent_port: int = typer.Option(8002, help="Agent node port"),
    specialties: str = typer.Option("general", help="Comma-separated list of specialties"),
    max_tasks: int = typer.Option(3, help="Maximum concurrent tasks"),
    node_id: Optional[str] = typer.Option(None, help="Custom node ID")
):
    """Start an agent node"""
    try:
        specialties_list = [s.strip() for s in specialties.split(",") if s.strip()]
        
        console.print(Panel(
            f"🤖 Starting Agent Node\n"
            f"Node ID: {node_id or 'auto-generated'}\n"
            f"Coordinator: {coordinator_host}:{coordinator_port}\n"
            f"Agent Port: {agent_port}\n"
            f"Specialties: {', '.join(specialties_list)}\n"
            f"Max Tasks: {max_tasks}",
            style="bold blue"
        ))
        
        node = DistributedAgentNode(
            node_id=node_id,
            coordinator_host=coordinator_host,
            coordinator_port=coordinator_port,
            agent_port=agent_port,
            specialties=specialties_list,
            max_concurrent_tasks=max_tasks
        )
        
        import uvicorn
        uvicorn.run(node.app, host="0.0.0.0", port=agent_port)
        
    except Exception as e:
        console.print(f"❌ Failed to start agent node: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def create_task(
    issue: int = typer.Option(..., help="GitHub issue number"),
    repo: str = typer.Option(..., help="Repository in format owner/repo"),
    priority: str = typer.Option("medium", help="Task priority (low, medium, high)"),
    distributed: bool = typer.Option(False, help="Use distributed processing"),
    coordinator_host: str = typer.Option("localhost", help="Coordinator host"),
    coordinator_port: int = typer.Option(8001, help="Coordinator port")
):
    """Create a new task from GitHub issue"""
    try:
        console.print(Panel(f"📝 Creating task from issue #{issue} in {repo}", style="bold blue"))
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Creating task...", total=None)
            
            # Initialize agent
            agent = DistributedAgent(
                use_distributed=distributed,
                coordinator_host=coordinator_host,
                coordinator_port=coordinator_port
            )
            
            progress.update(task, description="Fetching issue data...")
            
            # Create task
            task_id = agent.create_task_from_issue(issue, repo)
            
            progress.update(task, description="Task created!")
        
        console.print(f"✅ Task created with ID: [bold]{task_id}[/bold]")
        
        if distributed:
            console.print("🌐 Task will be processed using distributed cluster")
        else:
            console.print("💻 Task will be processed locally")
            
    except Exception as e:
        console.print(f"❌ Failed to create task: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def run_task(
    task_id: str = typer.Argument(..., help="Task ID to run"),
    distributed: bool = typer.Option(False, help="Use distributed processing"),
    coordinator_host: str = typer.Option("localhost", help="Coordinator host"),
    coordinator_port: int = typer.Option(8001, help="Coordinator port")
):
    """Run a specific task"""
    try:
        console.print(Panel(f"🚀 Running task {task_id}", style="bold blue"))
        
        # Initialize agent
        agent = DistributedAgent(
            use_distributed=distributed,
            coordinator_host=coordinator_host,
            coordinator_port=coordinator_port
        )
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            task = progress.add_task("Processing task...", total=None)
            
            if distributed:
                progress.update(task, description="Submitting to distributed cluster...")
                result = asyncio.run(agent.run_task_distributed(task_id))
            else:
                progress.update(task, description="Running with specialized agents...")
                result = agent.run_task(task_id)
        
        if result["success"]:
            console.print("✅ Task completed successfully!", style="bold green")
            
            if result.get("specialized_agent"):
                console.print(f"🎯 Used specialized agent: {result['specialized_agent']}")
            
            if result.get("distributed"):
                console.print("🌐 Processed by distributed cluster")
                
            if result.get("pull_request", {}).get("success"):
                console.print(f"📋 Pull request created: {result['pull_request'].get('pr_url')}")
        else:
            console.print(f"❌ Task failed: {result.get('error')}", style="bold red")
            
    except Exception as e:
        console.print(f"❌ Failed to run task: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def status(
    task_id: Optional[str] = typer.Option(None, help="Specific task ID"),
    show_cluster: bool = typer.Option(False, help="Show cluster status"),
    coordinator_host: str = typer.Option("localhost", help="Coordinator host"),
    coordinator_port: int = typer.Option(8001, help="Coordinator port")
):
    """Show task or cluster status"""
    try:
        agent = DistributedAgent(
            use_distributed=show_cluster,
            coordinator_host=coordinator_host,
            coordinator_port=coordinator_port
        )
        
        if task_id:
            # Show specific task status
            task = agent.state_manager.get_task(task_id)
            if task:
                console.print(Panel(f"📋 Task Status: {task_id}", style="bold blue"))
                
                table = Table()
                table.add_column("Property", style="cyan")
                table.add_column("Value", style="white")
                
                table.add_row("Status", task["status"])
                table.add_row("Created", task["created_at"])
                table.add_row("Issue", f"#{task['issue']['number']} - {task['issue']['title']}")
                table.add_row("Repository", task.get("repository", "N/A"))
                
                if task.get("error"):
                    table.add_row("Error", task["error"], style="red")
                
                console.print(table)
            else:
                console.print(f"❌ Task {task_id} not found", style="bold red")
        
        elif show_cluster:
            # Show cluster status
            cluster_status = agent.get_cluster_status()
            if cluster_status:
                console.print(Panel("🌐 Cluster Status", style="bold blue"))
                
                # Nodes table
                nodes_table = Table(title="Nodes")
                nodes_table.add_column("Node ID", style="cyan")
                nodes_table.add_column("Status", style="white")
                nodes_table.add_column("Specialties", style="green")
                nodes_table.add_column("Tasks", style="yellow")
                
                for node in cluster_status["node_details"]:
                    nodes_table.add_row(
                        node["node_id"],
                        node["status"],
                        ", ".join(node["specialties"]),
                        f"{len(node['current_tasks'])}/{node['max_concurrent_tasks']}"
                    )
                
                console.print(nodes_table)
                
                # Tasks summary
                tasks_table = Table(title="Tasks Summary")
                tasks_table.add_column("Status", style="cyan")
                tasks_table.add_column("Count", style="white")
                
                tasks = cluster_status["tasks"]
                tasks_table.add_row("Total", str(tasks["total"]))
                tasks_table.add_row("Pending", str(tasks["pending"]))
                tasks_table.add_row("Active", str(tasks["active"]))
                tasks_table.add_row("Completed", str(tasks["completed"]))
                
                console.print(tasks_table)
            else:
                console.print("❌ Not connected to cluster coordinator", style="bold red")
        
        else:
            # Show general status
            tasks = agent.state_manager.list_tasks()
            
            console.print(Panel("📊 Tasks Overview", style="bold blue"))
            
            table = Table()
            table.add_column("Task ID", style="cyan")
            table.add_column("Status", style="white")
            table.add_column("Issue", style="green")
            table.add_column("Created", style="yellow")
            
            for task in tasks:
                issue_info = f"#{task['issue']['number']} - {task['issue']['title'][:50]}..."
                table.add_row(
                    task["task_id"],
                    task["status"],
                    issue_info,
                    task["created_at"][:16]
                )
            
            console.print(table)
            
    except Exception as e:
        console.print(f"❌ Failed to get status: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def agents():
    """Show available specialized agents"""
    try:
        agent = DistributedAgent()
        agents_info = agent.get_available_agents()
        
        console.print(Panel("🤖 Available Specialized Agents", style="bold blue"))
        
        for agent_info in agents_info:
            table = Table(title=f"{agent_info['class']}")
            table.add_column("Property", style="cyan")
            table.add_column("Value", style="white")
            
            table.add_row("Name", agent_info["name"])
            table.add_row("Specialties", ", ".join(agent_info["specialties"]))
            table.add_row("Claude Model", agent_info["model"])
            table.add_row("File Patterns", str(len(agent_info["file_patterns"])) + " patterns")
            
            console.print(table)
            console.print()
            
    except Exception as e:
        console.print(f"❌ Failed to get agents info: {e}", style="bold red")
        raise typer.Exit(1)


@app.command()
def workflow(
    issue: int = typer.Option(..., help="GitHub issue number"),
    repo: str = typer.Option(..., help="Repository in format owner/repo"),
    distributed: bool = typer.Option(False, help="Use distributed processing"),
    coordinator_host: str = typer.Option("localhost", help="Coordinator host"),
    coordinator_port: int = typer.Option(8001, help="Coordinator port")
):
    """Complete workflow: create task and run it"""
    try:
        console.print(Panel(f"🔄 Complete workflow for issue #{issue} in {repo}", style="bold blue"))
        
        agent = DistributedAgent(
            use_distributed=distributed,
            coordinator_host=coordinator_host,
            coordinator_port=coordinator_port
        )
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            # Create task
            task = progress.add_task("Creating task...", total=None)
            task_id = agent.create_task_from_issue(issue, repo)
            progress.update(task, description=f"Task {task_id} created")
            
            # Run task
            progress.update(task, description="Running task...")
            if distributed:
                result = asyncio.run(agent.run_task_distributed(task_id))
            else:
                result = agent.run_task(task_id)
            
            progress.update(task, description="Workflow completed!")
        
        if result["success"]:
            console.print("✅ Workflow completed successfully!", style="bold green")
            
            if result.get("specialized_agent"):
                console.print(f"🎯 Used: {result['specialized_agent']}")
            
            if result.get("pull_request", {}).get("success"):
                console.print(f"📋 PR: {result['pull_request'].get('pr_url')}")
        else:
            console.print(f"❌ Workflow failed: {result.get('error')}", style="bold red")
            
    except Exception as e:
        console.print(f"❌ Workflow failed: {e}", style="bold red")
        raise typer.Exit(1)


if __name__ == "__main__":
    setup_logging()
    app()