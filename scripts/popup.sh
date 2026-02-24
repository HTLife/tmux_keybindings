#!/usr/bin/env bash
set -euo pipefail

# Preferred file format (YAML):
# actions:
#   - key: Prefix+g
#     description: Open lazygit
#     group: Git
#     omit: false
#     type: shell
#     command: lazygit
#
# Legacy format is still supported:
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

yaml_actions_to_legacy_rows() {
  local file_path="$1"
  awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function unquote(s, q) {
      s = trim(s)
      q = sprintf("%c", 39)
      if (s ~ /^".*"$/ || s ~ ("^" q ".*" q "$")) {
        return substr(s, 2, length(s) - 2)
      }
      return s
    }
    function is_true(s, t) {
      t = tolower(trim(s))
      return (t == "1" || t == "true" || t == "yes" || t == "on")
    }
    function emit() {
      if (key != "" && type != "" && cmd != "") {
        if (is_true(omit)) {
          key = ""; desc = ""; type = ""; cmd = ""; group = ""; omit = ""
          return
        }
        if (desc == "") { desc = key }
        if (group != "") { desc = "[" group "] " desc }
        print key "|" desc "|" type "|" cmd
      }
      key = ""; desc = ""; type = ""; cmd = ""; group = ""; omit = ""
    }
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    /^[[:space:]]*actions:[[:space:]]*$/ { in_actions = 1; next }
    !in_actions { next }
    /^[[:space:]]*-[[:space:]]*key:[[:space:]]*/ {
      emit()
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*key:[[:space:]]*/, "", line)
      key = unquote(line)
      next
    }
    /^[[:space:]]*(description|desc):[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*(description|desc):[[:space:]]*/, "", line)
      desc = unquote(line)
      next
    }
    /^[[:space:]]*group:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*group:[[:space:]]*/, "", line)
      group = unquote(line)
      next
    }
    /^[[:space:]]*omit:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*omit:[[:space:]]*/, "", line)
      omit = unquote(line)
      next
    }
    /^[[:space:]]*type:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*type:[[:space:]]*/, "", line)
      type = unquote(line)
      next
    }
    /^[[:space:]]*(command|cmd|payload):[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*(command|cmd|payload):[[:space:]]*/, "", line)
      cmd = unquote(line)
      next
    }
    END { emit() }
  ' "$file_path"
}

load_actions() {
  local file_path custom first_line
  file_path="$(tmux show-option -gqv @keybindings_popup_actions_file || true)"
  if [ -n "$file_path" ]; then
    # Expand "~" when configured from tmux options.
    case "$file_path" in
      "~"|"~/"*) file_path="${file_path/#\~/$HOME}" ;;
    esac
    if [ -f "$file_path" ]; then
      first_line="$(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$file_path" | head -n 1)"
      if [ "$first_line" = "actions:" ]; then
        yaml_actions_to_legacy_rows "$file_path"
      else
        sed -e '/^[[:space:]]*$/d' -e '/^[[:space:]]*#/d' "$file_path"
      fi
      return 0
    fi
  fi

  custom="$(tmux show-option -gqv @keybindings_popup_actions || true)"
  if [ -n "$custom" ]; then
    # Support both real newlines and "\n" escaped newlines from tmux.conf.
    printf '%b\n' "$custom" | sed '/^[[:space:]]*$/d'
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
    if (tolower(type) == "section" || tolower(type) == "group") {
      next
    }
    payload="";
    for (i=4; i<=NF; i++) {
      payload = payload ((i==4)?"":"|") $i;
    }
    if (payload == "") {
      next
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
    local mode out key selected
    mode="nav"

    while true; do
      if [ "$mode" = "nav" ]; then
        out="$(
          printf '%s\n' "$rows" | \
            FZF_DEFAULT_OPTS= fzf \
              --ansi \
              --no-multi \
              --disabled \
              --delimiter='\t' \
              --with-nth=1 \
              --expect='enter,esc,/' \
              --bind='j:down,k:up,ctrl-j:down,ctrl-k:up,start:clear-query,change:clear-query' \
              --prompt='Hotkeys > ' \
              --header='j/k: move, /: search, Enter: run, Esc: close' || true
        )"
      else
        out="$(
          printf '%s\n' "$rows" | \
            FZF_DEFAULT_OPTS= fzf \
              --ansi \
              --no-multi \
              --delimiter='\t' \
              --with-nth=1 \
              --expect='enter,esc,/' \
              --bind='ctrl-j:down,ctrl-k:up' \
              --prompt='Search > ' \
              --header='Type to search, /: back to nav, Enter: run, Esc: close' || true
        )"
      fi

      [ -z "$out" ] && return 0

      key="$(printf '%s\n' "$out" | sed -n '1p')"
      selected="$(printf '%s\n' "$out" | sed -n '2p')"

      if [ "$key" = "/" ]; then
        if [ "$mode" = "nav" ]; then
          mode="search"
        else
          mode="nav"
        fi
        continue
      fi

      if [ "$key" = "esc" ]; then
        if [ "$mode" = "search" ]; then
          mode="nav"
          continue
        fi
        return 0
      fi

      # Handle cases where fzf returns selected line without an expect key.
      if [ -z "$selected" ]; then
        selected="$key"
      fi

      if [ -n "$selected" ]; then
        printf '%s\n' "$selected"
        return 0
      fi
    done
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
