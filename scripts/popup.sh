#!/usr/bin/env bash
set -euo pipefail

# Format for action lines:
# Key|Description|Type|Payload
# Type: tmux, shell

default_actions() {
  cat <<'ACTIONS'
Prefix+c|Create window|tmux|new-window
Prefix+%|Split pane vertical|tmux|split-window -h
Prefix+"|Split pane horizontal|tmux|split-window -v
Prefix+o|Swap to next pane|tmux|select-pane -t :.+
Prefix+z|Zoom pane toggle|tmux|resize-pane -Z
Prefix+x|Kill pane|tmux|kill-pane
Prefix+&|Kill window|tmux|kill-window
Prefix+n|Next window|tmux|next-window
Prefix+p|Previous window|tmux|previous-window
Prefix+w|Window list|tmux|choose-window
Prefix+,|Rename window|tmux|command-prompt -I '#W' 'rename-window -- %%'
Prefix+$|Rename session|tmux|command-prompt -I '#S' 'rename-session -- %%'
Prefix+s|Session tree|tmux|choose-tree -s
Prefix+f|Find in windows|tmux|command-prompt 'find-window -- %%'
Prefix+r|Reload tmux config|tmux|source-file ~/.tmux.conf \; display-message 'tmux.conf reloaded'
ACTIONS
}

load_actions() {
  local custom
  custom="$(tmux show-option -gqv @keybindings_popup_actions || true)"
  if [ -n "$custom" ]; then
    printf '%s\n' "$custom"
  else
    default_actions
  fi
}

run_action() {
  local type="$1"
  local payload="$2"

  case "$type" in
    tmux)
      eval "tmux $payload"
      ;;
    shell)
      sh -c "$payload"
      ;;
    *)
      tmux display-message "Unknown action type: $type"
      return 1
      ;;
  esac
}

build_rows() {
  load_actions | awk -F'|' 'NF >= 4 {
    key=$1; desc=$2; type=$3;
    payload="";
    for (i=4; i<=NF; i++) {
      payload = payload ((i==4)?"":"|") $i;
    }
    printf "%-16s %-42s\t%s\t%s\n", key, desc, type, payload;
  }'
}

select_row() {
  local rows
  rows="$(build_rows)"

  if [ -z "$rows" ]; then
    tmux display-message "No keybinding actions configured"
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "$rows" | \
      fzf \
        --ansi \
        --no-multi \
        --delimiter='\t' \
        --with-nth=1 \
        --prompt='Hotkeys > ' \
        --header='Enter: run, Esc: close' || true
  else
    # Basic fallback selector when fzf is unavailable.
    local i=1
    local line
    while IFS= read -r line; do
      printf '%2d) %s\n' "$i" "${line%%$'\t'*}"
      i=$((i + 1))
    done <<< "$rows"

    printf '\nSelect number (blank to cancel): '
    read -r index
    if [ -z "${index:-}" ]; then
      return 0
    fi

    sed -n "${index}p" <<< "$rows"
  fi
}

main() {
  local selected
  selected="$(select_row)"

  if [ -z "$selected" ]; then
    exit 0
  fi

  local type payload
  type="$(printf '%s\n' "$selected" | cut -f2)"
  payload="$(printf '%s\n' "$selected" | cut -f3-)"

  run_action "$type" "$payload"
}

main "$@"
