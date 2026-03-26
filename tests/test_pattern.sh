#!/usr/bin/env bash
# Tests for detect_name_by_pattern function
# Run: bash tests/test_pattern.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

# Source the function by extracting it with awk
eval "$(awk '/^detect_name_by_pattern\(\)/,/^}/' "$SCRIPT_DIR/scripts/auto-name.sh")"

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $test_name"
        echo "  expected: '$expected'"
        echo "  actual:   '$actual'"
    fi
}

# ─── AI Tool Detection ───

assert_eq "detect claude-code" "claude" \
    "$(detect_name_by_pattern "Claude Code is active
Model: Opus 4.6 (1M context) | Ctx: 37.0k")"

assert_eq "detect claude code string" "claude" \
    "$(detect_name_by_pattern "Claude Code is running here")"

assert_eq "detect aider" "aider" \
    "$(detect_name_by_pattern "Aider v0.82.0
aider> /help")"

assert_eq "detect copilot" "copilot" \
    "$(detect_name_by_pattern "github.copilot extension loaded")"

assert_eq "detect chatgpt" "chatgpt" \
    "$(detect_name_by_pattern "chatgpt session started")"

assert_eq "detect gemini" "gemini" \
    "$(detect_name_by_pattern "google.ai gemini api")"

assert_eq "detect cursor" "cursor" \
    "$(detect_name_by_pattern "cursor editor running")"

# ─── Project Detection ───

assert_eq "project from path" "my-app" \
    "$(detect_name_by_pattern "~/Programming/user/my-app >")"

assert_eq "project from cd" "api-server" \
    "$(detect_name_by_pattern "cd ~/projects/api-server")"

assert_eq "project from git branch" "feat/auth-flow" \
    "$(detect_name_by_pattern "On branch feat/auth-flow
nothing to commit")"

# ─── Activity Detection ───

assert_eq "activity: test (jest)" "test" \
    "$(detect_name_by_pattern "npx jest --coverage")"

assert_eq "activity: test (pytest)" "test" \
    "$(detect_name_by_pattern "pytest tests/ -v")"

assert_eq "activity: build" "build" \
    "$(detect_name_by_pattern "npm run build
webpack compiled successfully")"

assert_eq "activity: docker" "docker" \
    "$(detect_name_by_pattern "docker-compose up -d")"

assert_eq "activity: k8s" "k8s" \
    "$(detect_name_by_pattern "kubectl get pods -n production")"

assert_eq "activity: deps" "deps" \
    "$(detect_name_by_pattern "npm install express")"

assert_eq "activity: git-sync" "git-sync" \
    "$(detect_name_by_pattern "git push origin feature-branch")"

assert_eq "activity: git" "git" \
    "$(detect_name_by_pattern "git status
Changes not staged for commit")"

assert_eq "activity: remote" "remote" \
    "$(detect_name_by_pattern "ssh user@server.com")"

assert_eq "activity: logs" "logs" \
    "$(detect_name_by_pattern "tail -f /var/log/app.log")"

assert_eq "activity: db" "db" \
    "$(detect_name_by_pattern "psql -h localhost mydb")"

assert_eq "activity: edit" "edit" \
    "$(detect_name_by_pattern "nvim config.yaml")"

assert_eq "activity: dev-server" "dev-server" \
    "$(detect_name_by_pattern "npm run dev
Local: http://localhost:3000")"

assert_eq "activity: run" "run" \
    "$(detect_name_by_pattern "node server.js")"

# ─── Name Composition ───

assert_eq "ai + project" "claude:my-app" \
    "$(detect_name_by_pattern "Model: claude-opus | ~/Programming/user/my-app")"

assert_eq "ai + activity" "claude:test" \
    "$(detect_name_by_pattern "Model: claude-opus
npx jest --coverage")"

assert_eq "ai only" "claude" \
    "$(detect_name_by_pattern "Claude Code session
some random output")"

assert_eq "project + activity" "api-server:docker" \
    "$(detect_name_by_pattern "cd ~/projects/api-server
docker-compose up")"

assert_eq "project only" "web-client" \
    "$(detect_name_by_pattern "~/Programming/org/web-client > ls")"

assert_eq "empty content" "" \
    "$(detect_name_by_pattern "")"

assert_eq "no match" "" \
    "$(detect_name_by_pattern "just a regular terminal with nothing special")"

# ─── Results ───

echo ""
echo "═══════════════════════════"
echo "Results: $PASS passed, $FAIL failed (total: $((PASS + FAIL)))"
echo "═══════════════════════════"

exit $FAIL
