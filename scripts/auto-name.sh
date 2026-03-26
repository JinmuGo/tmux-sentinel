#!/usr/bin/env bash
# Auto-name a pane by analyzing its content
# Pattern matching first (instant), LLM upgrade async (if available)
# Usage: auto-name.sh [-t target] [-m model] [--pattern-only]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults
TARGET=""
MODEL=""
PATTERN_ONLY=false
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t) TARGET="$2"; shift 2 ;;
        -m) MODEL="$2"; shift 2 ;;
        --pattern-only) PATTERN_ONLY=true; shift ;;
        *) shift ;;
    esac
done

# ─── Helpers ───

# Cross-platform md5 hash
_hash() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum | cut -d' ' -f1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -r | cut -d' ' -f1
    else
        # Fallback: use cksum
        cksum | cut -d' ' -f1
    fi
}

# Sanitize name: lowercase, allowed chars only, max 25 chars
_sanitize_name() {
    echo "$1" | \
        tr '[:upper:]' '[:lower:]' | \
        tr ' _' '-' | \
        sed 's/[^a-z0-9:-]//g' | \
        sed 's/--*/-/g; s/^-//; s/-$//' | \
        head -c 25
}

# Build tmux target args
_tmux_target() {
    if [ -n "$TARGET" ]; then
        echo "-t" "$TARGET"
    fi
}

# Check if all LLM dependencies are available
_check_llm_available() {
    curl -s --max-time 2 "${OLLAMA_HOST}/api/tags" >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    command -v python3 >/dev/null 2>&1 || return 1
    return 0
}

# ─── Content fingerprint ───

_get_fingerprint() {
    local content="$1"
    echo "$content" | grep -oE '[A-Za-z0-9._/-]{3,}' | sort -u | tr '\n' '|' | _hash
}

_fingerprint_changed() {
    local new_hash="$1"
    local old_hash
    if [ -n "$TARGET" ]; then
        old_hash=$(tmux display-message -p -t "$TARGET" '#{@pane_name_hash}' 2>/dev/null)
    else
        old_hash=$(tmux display-message -p '#{@pane_name_hash}' 2>/dev/null)
    fi
    [ "$new_hash" != "$old_hash" ]
}

_save_fingerprint() {
    local hash="$1"
    if [ -n "$TARGET" ]; then
        tmux set-option -p -t "$TARGET" @pane_name_hash "$hash"
    else
        tmux set-option -p @pane_name_hash "$hash"
    fi
}

# ─── Pattern-based naming (zero dependencies) ───

detect_name_by_pattern() {
    local content="$1"
    local ai_tool="" project="" activity=""

    # 1. Detect AI tool + project + activity in a single pass
    # AI tools
    if echo "$content" | grep -qiE "(claude-code|Claude Code|Model:.*claude)"; then
        ai_tool="claude"
    elif echo "$content" | grep -qiE "(aider>|Aider v|aider/)"; then
        ai_tool="aider"
    elif echo "$content" | grep -qiE "(copilot|github.copilot)"; then
        ai_tool="copilot"
    elif echo "$content" | grep -qiE "(chatgpt|openai)"; then
        ai_tool="chatgpt"
    elif echo "$content" | grep -qiE "(gemini|google.ai)"; then
        ai_tool="gemini"
    elif echo "$content" | grep -qiE "cursor"; then
        ai_tool="cursor"
    fi

    # 2. Extract project context
    project=$(echo "$content" | grep -oE '(Programming|projects|repos|src|code|workspace)/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+' | tail -1 | awk -F/ '{print $NF}')
    if [ -z "$project" ]; then
        project=$(echo "$content" | grep -oE 'cd [~./]*[A-Za-z0-9/_-]+' | tail -1 | awk -F/ '{print $NF}')
    fi
    if [ -z "$project" ]; then
        project=$(echo "$content" | grep -oE '\(?(main|master|develop|feat/[A-Za-z0-9_-]+|fix/[A-Za-z0-9_-]+|feature/[A-Za-z0-9_-]+)\)?' | tail -1 | tr -d '()')
    fi

    # 3. Detect activity — combined pattern for fewer grep calls
    local dev_match
    dev_match=$(echo "$content" | grep -oiE '(npm test|jest|pytest|cargo test|go test|rspec|vitest|npm run build|cargo build|go build|make |webpack|vite build|docker|docker-compose|podman|kubectl|k9s|helm|npm install|yarn add|pip install|cargo add|brew install|git push|git pull|git merge|git rebase|git diff|git log|git status|git stash|ssh |scp |rsync |tail -f|journalctl|logs|psql|mysql|sqlite|mongosh|redis-cli|vim |nvim |nano |emacs |node |python3? |ruby |go run|cargo run|java |deno |npm start|yarn start|npm run dev|yarn dev|pnpm dev)' | tail -1)

    if [ -n "$dev_match" ]; then
        case "$dev_match" in
            *test*|*jest*|*pytest*|*rspec*|*vitest*) activity="test" ;;
            *build*|*make*|*webpack*|*vite*) activity="build" ;;
            *docker*|*podman*) activity="docker" ;;
            *kubectl*|*k9s*|*helm*) activity="k8s" ;;
            *install*|*add*) activity="deps" ;;
            *"git push"*|*"git pull"*|*"git merge"*|*"git rebase"*) activity="git-sync" ;;
            *"git diff"*|*"git log"*|*"git status"*|*"git stash"*) activity="git" ;;
            *ssh*|*scp*|*rsync*) activity="remote" ;;
            *"tail -f"*|*journalctl*|*logs*) activity="logs" ;;
            *psql*|*mysql*|*sqlite*|*mongosh*|*redis*) activity="db" ;;
            *vim*|*nvim*|*nano*|*emacs*) activity="edit" ;;
            *start*|*dev*) activity="dev-server" ;;
            *node*|*python*|*ruby*|*"go run"*|*"cargo run"*|*java*|*deno*) activity="run" ;;
        esac
    fi

    # 4. Build the name
    local name=""
    if [ -n "$ai_tool" ] && [ -n "$project" ]; then
        name="${ai_tool}:${project}"
    elif [ -n "$ai_tool" ] && [ -n "$activity" ]; then
        name="${ai_tool}:${activity}"
    elif [ -n "$ai_tool" ]; then
        name="${ai_tool}"
    elif [ -n "$project" ] && [ -n "$activity" ]; then
        name="${project}:${activity}"
    elif [ -n "$project" ]; then
        name="${project}"
    elif [ -n "$activity" ]; then
        name="${activity}"
    fi

    echo "$name"
}

# ─── LLM-based naming (requires ollama) ───

detect_name_by_llm() {
    local content="$1"

    if [ -z "$MODEL" ]; then
        MODEL=$(tmux show-option -gqv "@pane-naming-model")
    fi
    if [ -z "$MODEL" ]; then
        MODEL="qwen2.5:0.5b"
    fi

    local trimmed
    trimmed=$(echo "$content" | tail -30 | head -c 2000)

    local prompt="Analyze this terminal session and generate a short descriptive name (2-4 words, lowercase, hyphens). Capture WHAT is being worked on. Examples: api-auth-fix, react-dashboard, docker-setup.

Terminal:
${trimmed}

Reply ONLY the name."

    local response_file
    response_file=$(mktemp)

    curl -s --max-time 15 "${OLLAMA_HOST}/api/chat" \
        -d "$(jq -n \
            --arg model "$MODEL" \
            --arg prompt "$prompt" \
            '{
                model: $model,
                messages: [{role: "user", content: $prompt}],
                stream: false,
                think: false,
                options: {temperature: 0.3, num_predict: 30}
            }')" \
        > "$response_file" 2>/dev/null

    if [ ! -s "$response_file" ]; then
        rm -f "$response_file"
        return 1
    fi

    # Pass file path as argument to python, not string interpolation
    local name
    name=$(python3 - "$response_file" <<'PYEOF'
import json, sys
fpath = sys.argv[1]
with open(fpath, 'r') as f:
    data = json.JSONDecoder(strict=False).decode(f.read())
content = data.get('message', {}).get('content', '')
content = content.strip().strip('"').strip("'").split('\n')[0].strip()
print(content[:25])
PYEOF
    )

    rm -f "$response_file"
    echo "$name"
}

# ─── Main ───

# Build tmux capture command
capture_args=(-p -J -S -50)
if [ -n "$TARGET" ]; then
    capture_args+=(-t "$TARGET")
fi

# Capture pane content
pane_content=$(tmux capture-pane "${capture_args[@]}" 2>/dev/null)
if [ -z "$pane_content" ]; then
    exit 0
fi

# Check fingerprint — skip if content hasn't changed
new_hash=$(_get_fingerprint "$pane_content")
if ! _fingerprint_changed "$new_hash"; then
    exit 0
fi

# Save new fingerprint
_save_fingerprint "$new_hash"

# Step 1: Pattern matching (instant, synchronous)
name=$(detect_name_by_pattern "$pane_content")

if [ -n "$name" ]; then
    name=$(_sanitize_name "$name")
    if [ -n "$TARGET" ]; then
        tmux set-option -p -t "$TARGET" @pane_name "$name"
    else
        tmux set-option -p @pane_name "$name"
    fi
fi

# Step 2: LLM upgrade (async, non-blocking)
if [ "$PATTERN_ONLY" = false ] && _check_llm_available; then
    (
        llm_name=$(detect_name_by_llm "$pane_content")
        if [ -n "$llm_name" ]; then
            llm_name=$(_sanitize_name "$llm_name")
            if [ -n "$TARGET" ]; then
                tmux set-option -p -t "$TARGET" @pane_name "$llm_name"
            else
                tmux set-option -p @pane_name "$llm_name"
            fi
        fi
    ) &
fi

# Show result only for manual triggers (not focus/interval)
if [ -z "$AUTO_TRIGGER" ] && [ -n "$name" ]; then
    tmux display-message "pane named: ${name}"
fi
