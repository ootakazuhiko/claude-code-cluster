#!/usr/bin/env python3
"""Setup script for Claude Code Cluster PoC"""

import os
import subprocess
import sys
from pathlib import Path


def run_command(cmd, description=""):
    """Run a command and handle errors"""
    print(f"Running: {' '.join(cmd)}")
    if description:
        print(f"  {description}")
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Error: {result.stderr}")
        sys.exit(1)
    
    if result.stdout:
        print(result.stdout)
    
    return result


def check_prerequisites():
    """Check if required tools are installed"""
    print("Checking prerequisites...")
    
    required_tools = [
        ("python3", "Python 3.11+"),
        ("git", "Git"),
        ("uv", "uv (Python package manager)")
    ]
    
    missing_tools = []
    
    for tool, description in required_tools:
        try:
            result = subprocess.run([tool, "--version"], capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✓ {tool}: {result.stdout.strip()}")
            else:
                missing_tools.append((tool, description))
        except FileNotFoundError:
            missing_tools.append((tool, description))
    
    if missing_tools:
        print("\nMissing required tools:")
        for tool, description in missing_tools:
            print(f"  - {tool}: {description}")
        print("\nPlease install the missing tools and try again.")
        sys.exit(1)
    
    print("✓ All prerequisites satisfied")


def setup_environment():
    """Setup Python environment and install dependencies"""
    print("\nSetting up environment...")
    
    # Install dependencies
    run_command(["uv", "sync"], "Installing dependencies")
    
    # Install development dependencies
    run_command(["uv", "sync", "--group", "dev"], "Installing development dependencies")
    
    print("✓ Environment setup complete")


def create_env_file():
    """Create .env file from template"""
    print("\nSetting up environment file...")
    
    env_file = Path(".env")
    env_example = Path(".env.example")
    
    if env_file.exists():
        print("✓ .env file already exists")
        return
    
    if env_example.exists():
        # Copy example file
        env_content = env_example.read_text()
        env_file.write_text(env_content)
        print("✓ Created .env file from .env.example")
        print("  Please edit .env file to add your API keys:")
        print("  - GITHUB_TOKEN: Your GitHub personal access token")
        print("  - ANTHROPIC_API_KEY: Your Claude API key")
    else:
        print("Warning: .env.example not found")


def setup_git_hooks():
    """Setup git hooks"""
    print("\nSetting up git hooks...")
    
    try:
        run_command(["uv", "run", "pre-commit", "install"], "Installing pre-commit hooks")
        print("✓ Git hooks installed")
    except:
        print("Warning: Failed to install git hooks (pre-commit not available)")


def run_tests():
    """Run basic tests"""
    print("\nRunning tests...")
    
    try:
        run_command(["uv", "run", "pytest", "tests/", "-v"], "Running tests")
        print("✓ All tests passed")
    except:
        print("Warning: Some tests failed")


def main():
    """Main setup function"""
    print("Claude Code Cluster PoC Setup")
    print("=" * 40)
    
    # Check prerequisites
    check_prerequisites()
    
    # Setup environment
    setup_environment()
    
    # Create .env file
    create_env_file()
    
    # Setup git hooks
    setup_git_hooks()
    
    # Run tests
    run_tests()
    
    print("\n" + "=" * 40)
    print("Setup completed successfully!")
    print("\nNext steps:")
    print("1. Edit .env file to add your API keys")
    print("2. Test the setup: uv run python -m src.main setup")
    print("3. Create a task: uv run python -m src.main create-task --issue 1 --repo owner/repo")
    print("4. Run a task: uv run python -m src.main run-task --task-id <task-id>")
    print("\nFor more information, see README.md")


if __name__ == "__main__":
    main()