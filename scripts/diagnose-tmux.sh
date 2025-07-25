#!/bin/bash
# Diagnose tmux issues

printf "=== TMUX Diagnosis ===\n\n"

# Check tmux version and permissions
printf "1. TMUX Information:\n"
printf "   Path: $(which tmux)\n"
printf "   Version: $(tmux -V)\n"
printf "   Permissions: $(ls -l $(which tmux))\n"

# Check tmux socket directory
printf "\n2. TMUX Socket Directory:\n"
TMUX_TMPDIR="${TMUX_TMPDIR:-/tmp}"
printf "   TMUX_TMPDIR: $TMUX_TMPDIR\n"
printf "   Socket path: $TMUX_TMPDIR/tmux-$(id -u)\n"
printf "   Directory exists: "
if [ -d "$TMUX_TMPDIR/tmux-$(id -u)" ]; then
    printf "Yes\n"
    printf "   Permissions: $(ls -ld $TMUX_TMPDIR/tmux-$(id -u))\n"
else
    printf "No\n"
fi

# Check environment
printf "\n3. Environment:\n"
printf "   USER: $USER\n"
printf "   HOME: $HOME\n"
printf "   UID: $(id -u)\n"
printf "   SHELL: $SHELL\n"

# Try to create tmux session manually
printf "\n4. Testing TMUX:\n"

# Method 1: Basic test
printf "   Basic test: "
if tmux new-session -d -s test123 'echo test' 2>/dev/null; then
    printf "Success\n"
    tmux kill-session -t test123 2>/dev/null
else
    printf "Failed\n"
fi

# Method 2: With explicit socket
printf "   With socket: "
if tmux -S /tmp/tmux-test new-session -d -s test456 'echo test' 2>/dev/null; then
    printf "Success (socket: /tmp/tmux-test)\n"
    tmux -S /tmp/tmux-test kill-session -t test456 2>/dev/null
    rm -f /tmp/tmux-test
else
    printf "Failed\n"
fi

# Check for stale sockets
printf "\n5. Checking for stale sockets:\n"
find /tmp -name "tmux-*" -type d 2>/dev/null | while read dir; do
    printf "   Found: $dir\n"
done

# System info
printf "\n6. System Information:\n"
printf "   OS: $(uname -a)\n"
printf "   /tmp permissions: $(ls -ld /tmp)\n"

# Recommendations
printf "\n=== Recommendations ===\n"
printf "1. Clear tmux sockets:\n"
printf "   rm -rf /tmp/tmux-$(id -u)\n"
printf "\n2. Start tmux manually:\n"
printf "   tmux new-session -s test\n"
printf "   (then detach with Ctrl+B, D)\n"
printf "\n3. Use explicit socket:\n"
printf "   TMUX_TMPDIR=$HOME tmux new-session -s cc01-github\n"