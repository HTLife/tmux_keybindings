#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bind_popup_key() {
  local key="$1"

  # Newer tmux supports popup title (-T). Fallback for older versions.
  tmux bind-key "$key" display-popup \
    -w "$popup_width" \
    -h "$popup_height" \
    -T "$popup_title" \
    -E "$CURRENT_DIR/scripts/popup.sh" 2>/dev/null && return 0

  tmux bind-key "$key" display-popup \
    -w "$popup_width" \
    -h "$popup_height" \
    -E "$CURRENT_DIR/scripts/popup.sh" 2>/dev/null && return 0

  # Last-resort fallback for tmux without popup support.
  tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/popup.sh" 2>/dev/null && return 0

  return 1
}

# User options
trigger_key="$(tmux show-option -gqv @keybindings_popup_trigger)"
if [ -z "$trigger_key" ]; then
  trigger_key="h"
fi

popup_width="$(tmux show-option -gqv @keybindings_popup_width)"
if [ -z "$popup_width" ]; then
  popup_width="80%"
fi

popup_height="$(tmux show-option -gqv @keybindings_popup_height)"
if [ -z "$popup_height" ]; then
  popup_height="80%"
fi

popup_title="$(tmux show-option -gqv @keybindings_popup_title)"
if [ -z "$popup_title" ]; then
  popup_title="TMUX Hotkeys"
fi

# Keep bindings in sync when config is reloaded and trigger option changes.
previous_trigger="$(tmux show-option -gqv @keybindings_popup_bound_trigger)"
if [ -n "$previous_trigger" ] && [ "$previous_trigger" != "$trigger_key" ]; then
  tmux unbind-key -q "$previous_trigger"
fi

# Remove stale default uppercase binding when trigger is no longer default.
if [ "$trigger_key" != "h" ]; then
  tmux unbind-key -q "H"
fi

# Bind the trigger key to open the popup TUI.
tmux unbind-key -q "$trigger_key"
bind_popup_key "$trigger_key" || tmux display-message "tmux_keybindings: failed to bind key $trigger_key"

# Also bind uppercase H when default trigger is used for convenience.
if [ "$trigger_key" = "h" ]; then
  tmux unbind-key -q "H"
  bind_popup_key "H" || tmux display-message "tmux_keybindings: failed to bind key H"
fi

tmux set-option -gq @keybindings_popup_bound_trigger "$trigger_key"

# Re-apply bindings after source-file completes so user options set later in
# .tmux.conf are picked up.
tmux set-hook -gq after-source-file "run-shell '$CURRENT_DIR/keybindings_popup.tmux'" 2>/dev/null || true

exit 0
