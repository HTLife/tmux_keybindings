#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# Bind the trigger key to open the popup TUI.
tmux bind-key "$trigger_key" display-popup \
  -w "$popup_width" \
  -h "$popup_height" \
  -T "$popup_title" \
  -E "$CURRENT_DIR/scripts/popup.sh"

# Also bind uppercase H when default trigger is used for convenience.
if [ "$trigger_key" = "h" ]; then
  tmux bind-key "H" display-popup \
    -w "$popup_width" \
    -h "$popup_height" \
    -T "$popup_title" \
    -E "$CURRENT_DIR/scripts/popup.sh"
fi
