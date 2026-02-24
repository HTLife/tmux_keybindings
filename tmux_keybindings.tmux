#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TPM entrypoint: execute the plugin bootstrap shell script.
tmux run-shell "$CURRENT_DIR/keybindings_popup.tmux"
