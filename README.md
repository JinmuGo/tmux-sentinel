# tmux-pane-naming

Name your tmux panes and see the names displayed on the pane borders. Smart auto-naming analyzes your terminal content and generates descriptive names — no dependencies required.

## Features

- **Smart auto-naming**: Analyzes pane content and generates descriptive names automatically
- **Zero-dependency mode**: Pattern matching detects AI tools, projects, git branches, and activities using only bash
- **LLM mode (optional)**: Uses a local ollama model for more accurate naming when available
- **AI session detection**: Recognizes Claude, Aider, Copilot, ChatGPT, Cursor, Gemini sessions
- **Manual naming**: Name panes with a simple keybinding prompt
- **Customizable colors**: Match your tmux theme with fg/bg options
- Background watch daemon for continuous auto-naming

## Requirements

- tmux 3.2+
- **Optional**: [ollama](https://ollama.ai) + `jq` + `python3` for LLM-powered naming

## Installation

### With TPM

Add to `~/.tmux.conf`:

```tmux
set -g @plugin 'JinmuGo/tmux-pane-naming'
```

Then press `prefix + I` to install.

### Manual

```bash
git clone https://github.com/JinmuGo/tmux-pane-naming ~/.tmux/plugins/tmux-pane-naming
```

Add to `~/.tmux.conf`:

```tmux
run-shell ~/.tmux/plugins/tmux-pane-naming/pane-naming.tmux
```

Reload: `tmux source-file ~/.tmux.conf`

## Usage

### Keybindings

| Keybinding | Action |
|---|---|
| `prefix + N` | Manual name input (opens prompt) |
| `prefix + Alt-N` | Auto-name current pane |
| `prefix + Ctrl-n` | Auto-name all AI session panes |
| `prefix + Alt-n` | Clear pane name |

### Programmatic Usage

```bash
# Auto-name current pane
~/.tmux/plugins/tmux-pane-naming/scripts/auto-name.sh

# Auto-name a specific pane
~/.tmux/plugins/tmux-pane-naming/scripts/auto-name.sh -t %3

# Auto-name all unnamed AI session panes
~/.tmux/plugins/tmux-pane-naming/scripts/auto-name-all.sh

# Start background watcher (auto-names every 60s)
~/.tmux/plugins/tmux-pane-naming/scripts/watch-panes.sh 60 &

# Manual rename
~/.tmux/plugins/tmux-pane-naming/scripts/rename-pane.sh "my-server"
~/.tmux/plugins/tmux-pane-naming/scripts/rename-pane.sh -t %3 "my-server"

# Clear name
~/.tmux/plugins/tmux-pane-naming/scripts/clear-pane-name.sh

# List all named panes
~/.tmux/plugins/tmux-pane-naming/scripts/list-pane-names.sh
```

## Configuration

Add these to `~/.tmux.conf` before the plugin is loaded:

```tmux
# Ollama model for LLM naming (default: qwen2.5:0.5b)
set -g @pane-naming-model "qwen2.5:0.5b"

# Key to trigger manual rename prompt (default: N)
set -g @pane-naming-key "N"

# Label foreground color (default: #1a1b26)
set -g @pane-naming-fg "#1a1b26"

# Label background color (default: #7aa2f7)
set -g @pane-naming-bg "#7aa2f7"

# Border status position: top or bottom (default: bottom)
set -g @pane-naming-border-status "bottom"
```

### Color presets

| Theme | fg | bg |
|---|---|---|
| Tokyo Night (default) | `#1a1b26` | `#7aa2f7` |
| Catppuccin Mocha | `#1e1e2e` | `#89b4fa` |
| Dracula | `#282a36` | `#bd93f9` |
| Nord | `#2e3440` | `#88c0d0` |
| Gruvbox | `#282828` | `#d79921` |
| Rose Pine | `#191724` | `#c4a7e7` |

## How auto-naming works

### Pattern matching (default, zero dependencies)

Analyzes pane content using regex to detect:

| Category | Detected patterns |
|---|---|
| AI tools | Claude Code, Aider, Copilot, ChatGPT, Cursor, Gemini |
| Projects | Directory paths, git repo names |
| Git | Branch names (feat/, fix/, main, develop) |
| Activities | test, build, docker, k8s, git, db, logs, dev-server, ssh, edit |

Generates names like `claude:my-project`, `api-server:test`, `docker`.

### LLM mode (optional, requires ollama)

When ollama is running, the plugin sends the last 30 lines of pane content to a local model for more context-aware naming. Falls back to pattern matching if ollama is unavailable.

Recommended lightweight model:

```bash
ollama pull qwen2.5:0.5b  # 393MB, fast enough for naming
```

All processing happens locally. No data leaves your machine.

## License

MIT
