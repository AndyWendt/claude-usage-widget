#!/bin/bash
# claude-usage-json.sh - Get Claude Max usage limits as JSON

SESSION_NAME="claude-usage-$$"

# Start claude in detached tmux session
tmux new-session -d -s "$SESSION_NAME" 'claude' 2>/dev/null
sleep 4

# Send /usage command
tmux send-keys -t "$SESSION_NAME" '/usage'
sleep 1
tmux send-keys -t "$SESSION_NAME" Enter
sleep 3

# Capture output
OUTPUT=$(tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null)

# Kill the session
tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# Parse percentages (use -A2 to handle blank lines)
SESSION_PCT=$(echo "$OUTPUT" | grep -A2 "Current session" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
WEEK_ALL_PCT=$(echo "$OUTPUT" | grep -A2 "Current week (all models)" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
WEEK_SONNET_PCT=$(echo "$OUTPUT" | grep -A2 "Current week (Sonnet only)" | grep -oE '[0-9]+%' | head -1 | tr -d '%')

# Parse reset times
SESSION_RESET=$(echo "$OUTPUT" | grep -A3 "Current session" | grep "Resets" | sed 's/.*Resets //' | head -1)
WEEK_ALL_RESET=$(echo "$OUTPUT" | grep -A3 "Current week (all models)" | grep "Resets" | sed 's/.*Resets //' | head -1)
WEEK_SONNET_RESET=$(echo "$OUTPUT" | grep -A3 "Current week (Sonnet only)" | grep "Resets" | sed 's/.*Resets //' | head -1)

# Output JSON
cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "session": {
    "percent_used": ${SESSION_PCT:-0},
    "resets": "${SESSION_RESET:-unknown}"
  },
  "week_all_models": {
    "percent_used": ${WEEK_ALL_PCT:-0},
    "resets": "${WEEK_ALL_RESET:-unknown}"
  },
  "week_sonnet": {
    "percent_used": ${WEEK_SONNET_PCT:-0},
    "resets": "${WEEK_SONNET_RESET:-unknown}"
  }
}
EOF
