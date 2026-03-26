#!/usr/bin/env bash
# List all panes with their names
# Output format: session:window.pane  %id  name

tmux list-panes -a -F "#{session_name}:#{window_index}.#{pane_index}  #{pane_id}  #{@pane_name}" | \
    while IFS= read -r line; do
        # Only show panes that have a name set
        name=$(echo "$line" | awk '{print $3}')
        if [ -n "$name" ]; then
            echo "$line"
        fi
    done
