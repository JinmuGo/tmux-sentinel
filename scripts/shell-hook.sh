#!/usr/bin/env bash
# Shell preexec hook: auto-name pane when an AI command is launched
# Source this in your shell rc or add to preexec:
#   eval "$(~/.tmux/plugins/tmux-pane-naming/scripts/shell-hook.sh init)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$1" = "init" ]; then
    cat <<'SHELL_HOOK'
# tmux-pane-naming: auto-name on AI session start
_tmux_pane_naming_preexec() {
    # Only run inside tmux
    [ -z "$TMUX" ] && return

    local cmd="$1"
    local naming_dir
    naming_dir=$(tmux show-environment -g TMUX_PANE_NAMING_DIR 2>/dev/null | cut -d= -f2)
    [ -z "$naming_dir" ] && return

    # Check if command starts an AI session
    case "$cmd" in
        claude|claude\ *|aider|aider\ *|chatgpt|chatgpt\ *|copilot|copilot\ *|cursor|cursor\ *|gemini|gemini\ *)
            # Skip if pane already named
            local existing
            existing=$(tmux display-message -p '#{@pane_name}' 2>/dev/null)
            [ -n "$existing" ] && return

            # Delay slightly so the AI tool has time to print output
            (sleep 3 && "$naming_dir/scripts/auto-name.sh") &
            ;;
    esac
}

# Install into bash preexec (requires bash-preexec) or zsh
if [ -n "$ZSH_VERSION" ]; then
    autoload -Uz add-zsh-hook
    # Wrap for zsh preexec (receives full command line)
    _tmux_pane_naming_zsh_preexec() {
        _tmux_pane_naming_preexec "$1"
    }
    add-zsh-hook preexec _tmux_pane_naming_zsh_preexec
elif [ -n "$BASH_VERSION" ]; then
    # Requires bash-preexec (https://github.com/rcaloras/bash-preexec)
    if declare -F __bp_precmd_invoke_cmd &>/dev/null; then
        preexec_functions+=(_tmux_pane_naming_preexec)
    fi
fi
SHELL_HOOK
    exit 0
fi
