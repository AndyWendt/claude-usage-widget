#!/bin/bash
# claude-usage-compact.sh - Compact Claude usage for status bars
# Output format: "Claude: 8% | Week: 40%"

SESSION_NAME="claude-usage-$$"

tmux new-session -d -s "$SESSION_NAME" 'claude' 2>/dev/null
sleep 4
tmux send-keys -t "$SESSION_NAME" '/usage'
sleep 1
tmux send-keys -t "$SESSION_NAME" Enter
sleep 3
OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null)
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

SESSION_PCT=$(echo "$OUTPUT" | grep -A2 "Current session" | grep -oE '[0-9]+%' | head -1)
WEEK_PCT=$(echo "$OUTPUT" | grep -A2 "Current week (all models)" | grep -oE '[0-9]+%' | head -1)

echo "Claude: ${SESSION_PCT:-?} | Week: ${WEEK_PCT:-?}"
