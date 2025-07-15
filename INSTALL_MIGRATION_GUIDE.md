# Installation Script Migration Guide

## Overview

The improved installation script (v2.0.0) addresses the following issues from the original script:

1. **Flexibility**: Support for custom installation directories and configurations
2. **Error Handling**: Better error tracking and recovery options
3. **Non-root Support**: Can run without sudo privileges
4. **Interactive/Non-interactive**: Support for automated deployments
5. **OS Compatibility**: Better detection and support for various Linux distributions

## Key Improvements

### 1. Command Line Options

The new installer supports various options for flexible installation:

```bash
# Show all available options
./install-improved.sh --help

# Install without sudo (for non-root users)
./install-improved.sh --no-sudo

# Install to custom directory
./install-improved.sh --dir /opt/claude-cluster

# Non-interactive installation (automated)
./install-improved.sh --yes

# Skip system dependencies (if already installed)
./install-improved.sh --skip-deps

# Force reinstall
./install-improved.sh --force
```

### 2. Error Handling

- **Error Tracking**: All errors are collected and displayed at the end
- **Partial Success**: Installation continues even if some components fail
- **Recovery Options**: Failed steps can be retried manually
- **Detailed Messages**: Clear error messages with troubleshooting hints

### 3. Non-root User Support

The improved script can run without sudo:

```bash
# For users without sudo access
./install-improved.sh --no-sudo

# Installation will:
# - Skip system package installation
# - Create directories in user space
# - Provide instructions for manual setup
```

### 4. Better OS Detection

- Supports more Linux distributions
- Detects Windows (WSL/Git Bash)
- Provides specific instructions per OS
- Falls back gracefully for unknown systems

## Migration Steps

### For Existing Installations

1. **Backup your configuration**:
   ```bash
   cp ~/.env ~/.env.backup
   cp -r claude-code-cluster claude-code-cluster.backup
   ```

2. **Run the new installer with force flag**:
   ```bash
   ./install-improved.sh --force
   ```

3. **Restore your configuration**:
   ```bash
   cp ~/.env.backup claude-code-cluster/.env
   ```

### For New Installations

1. **Download the new installer**:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/install-improved.sh -o install.sh
   chmod +x install.sh
   ```

2. **Run with your preferred options**:
   ```bash
   # Standard installation
   ./install.sh

   # Custom installation
   ./install.sh --dir ~/my-claude-cluster --no-sudo
   ```

## Common Scenarios

### Scenario 1: Corporate Environment (No Sudo)

```bash
# Install without sudo, skip system deps
./install-improved.sh --no-sudo --skip-deps

# The installer will:
# - Use existing Python installation
# - Create venv in user directory
# - Skip system package installation
# - Provide manual setup instructions
```

### Scenario 2: Automated Deployment

```bash
# Non-interactive installation
./install-improved.sh \
  --yes \
  --dir /opt/claude-cluster \
  --skip-deps

# Perfect for CI/CD pipelines
```

### Scenario 3: Development Environment

```bash
# Install with custom paths
./install-improved.sh \
  --dir ~/projects/claude-cluster \
  --venv .venv \
  --force
```

## Troubleshooting

### Error: Permission Denied

```bash
# Use --no-sudo flag
./install-improved.sh --no-sudo

# Or run as regular user
sudo -u myuser ./install-improved.sh
```

### Error: Python Not Found

```bash
# Skip dependency installation and use existing Python
./install-improved.sh --skip-deps

# Manually specify Python path
export PATH=/usr/local/bin:$PATH
./install-improved.sh
```

### Error: Git Clone Failed

```bash
# Check git credentials
git config --global credential.helper cache

# Or clone manually first
git clone https://github.com/ootakazuhiko/claude-code-cluster.git
cd claude-code-cluster
./install-improved.sh --dir .
```

## Wrapper Script

For even simpler installation, use the wrapper script:

```bash
# Auto-detects environment and adjusts
curl -fsSL https://raw.githubusercontent.com/ootakazuhiko/claude-code-cluster/main/install-wrapper.sh | bash

# Or download and run
curl -fsSL ... -o install-wrapper.sh
chmod +x install-wrapper.sh
./install-wrapper.sh
```

## Feature Comparison

| Feature | Original (v1.0) | Improved (v2.0) |
|---------|----------------|-----------------|
| Command line options | ❌ | ✅ |
| Non-root support | ❌ | ✅ |
| Error recovery | ❌ | ✅ |
| Custom paths | ❌ | ✅ |
| Non-interactive mode | ❌ | ✅ |
| OS detection | Basic | Advanced |
| Error messages | Basic | Detailed |
| Shell integration | ❌ | ✅ |
| Partial success | ❌ | ✅ |
| Dry run mode | ❌ | ✅ |

## Best Practices

1. **Always backup** before upgrading
2. **Test in dev** environment first
3. **Use --no-sudo** for shared systems
4. **Check logs** if installation fails
5. **Report issues** on GitHub

## Security Considerations

While the current installer downloads scripts and GPG keys directly, we prioritize usability for the initial release. Future versions may include:

- Script checksum verification
- GPG key fingerprint validation
- Pinned version downloads

For security-conscious users, we recommend:

1. Clone the repository manually: `git clone https://github.com/ootakazuhiko/claude-code-cluster.git`
2. Review the scripts before execution
3. Run the installer locally: `./install-improved.sh`

## Getting Help

If you encounter issues:

1. Run with verbose mode: `bash -x ./install-improved.sh`
2. Check error summary at the end
3. Review logs in `~/claude-code-cluster/logs/`
4. Open issue at: https://github.com/ootakazuhiko/claude-code-cluster/issues

---

**Note**: The original install.sh is preserved for backward compatibility. The improved version will become the default in future releases.