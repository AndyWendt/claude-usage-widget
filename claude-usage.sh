#!/bin/bash
# claude-usage.sh - Get Claude Max usage limits via tmux

SESSION_NAME="claude-usage-$$"

# Start claude in detached tmux session
tmux new-session -d -s "$SESSION_NAME" 'claude' 2>/dev/null

# Wait for claude to start
sleep 4

# Send /usage command
tmux send-keys -t "$SESSION_NAME" '/usage'
sleep 1
tmux send-keys -t "$SESSION_NAME" Enter
sleep 3

# Capture and parse output
OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null)

# Kill the session
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# Parse the output for usage info
echo "$OUTPUT" | grep -E "(Current session|Current week|% used|Resets)" | \
    sed 's/^[[:space:]]*//' | \
    grep -v "^$"
