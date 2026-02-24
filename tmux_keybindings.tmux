#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# TPM entrypoint: delegate to the actual plugin script.
tmux source-file "$CURRENT_DIR/keybindings_popup.tmux"
