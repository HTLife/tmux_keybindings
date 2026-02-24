# tmux-keybindings-popup

A tmux plugin that opens a lazygit-style popup TUI to browse hotkeys and execute the selected action.

## Features

- Opens in `tmux display-popup`
- Shows key + description list
- Execute selected action directly
- Supports custom actions via tmux option
- Uses `fzf` if installed, with a plain selector fallback

## Install

### TPM

```tmux
set -g @plugin 'HTLife/tmux_keybindings'
set -g @keybindings_popup_trigger '?'
run '~/.tmux/plugins/tpm/tpm'
```

Then inside tmux press `Prefix + I` to install plugins.

Tip: keep plugin options above the TPM `run` line.

### Manual

```tmux
run-shell '/path/to/tmux_keybindings/keybindings_popup.tmux'
```

## Default Trigger

- `Prefix + h` (also binds `Prefix + H` by default)

Change it:

```tmux
set -g @keybindings_popup_trigger '?'
```

## Options

```tmux
set -g @keybindings_popup_width '80%'
set -g @keybindings_popup_height '80%'
set -g @keybindings_popup_title 'TMUX Hotkeys'
```

## Custom Actions

Provide newline-separated actions:

`Key|Description|Type|Payload`

- `Type`: `tmux` or `shell`
- `Payload`: tmux command args (for `tmux`) or shell command (for `shell`)

Example:

```tmux
set -g @keybindings_popup_actions "\
Prefix+g|Open lazygit|shell|lazygit\
Prefix+t|New scratch window|tmux|new-window -n scratch\
Prefix+v|Split and run htop|tmux|split-window -h 'htop'\
"
```

## Notes

- `fzf` is optional but recommended for a better picker UI.
- If no custom actions are configured, sensible defaults are shown.
