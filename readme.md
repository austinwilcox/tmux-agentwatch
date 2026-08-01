# tmux-agentwatch

Know which tmux pane has an agent waiting on you.

When you run several coding agents at once, tmux can only tell you a pane produced
output — not whether the agent finished, wants permission, or is still grinding.
`agentwatch` takes state straight from the agent's own hooks, flags the window,
sends a desktop notification, and gives you one key to jump to whoever has been
waiting longest.

```
  1  ● waiting     2m  work:3.1             api-gateway
  2  ✔ done       14s  work:1.2             docs-site
  3  … working     8m  side:1.1             leftwm
```

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

Add to your `~/.tmux.conf`:

```tmux
set -g @plugin 'austinwilcox/tmux-agentwatch'
```

Press `prefix + I`, then wire up your agent:

```bash
~/.tmux/plugins/tmux-agentwatch/scripts/agentwatch hooks --write
```

### Standalone

```bash
./install.sh                  # installs to ~/.local/bin
./install.sh /usr/local/bin   # or a custom directory
agentwatch hooks --write      # wire up Claude Code
agentwatch doctor             # confirm the setup (run this inside tmux)
```

## How it works

Claude Code fires a hook on every state change, and hook processes inherit the
pane's environment — including `$TMUX_PANE`. So `agentwatch` knows exactly which
pane an event came from without scraping a single byte of terminal output.

| Claude Code hook | agentwatch state |
|---|---|
| `UserPromptSubmit` | `working` |
| `Notification` (permission request, idle prompt) | `waiting` |
| `Stop` / `SubagentStop` | `done` |

`agentwatch hooks --write` merges that config into `~/.claude/settings.json`. It
backs the file up first, preserves any hooks you already had, and is safe to run
more than once. Run `agentwatch hooks` without `--write` to print the JSON instead.

Each transition:

- writes a record to `~/.local/state/agentwatch/pane-<id>`
- sets `@agentwatch_state`, `@agentwatch_glyph`, `@agentwatch_color` and
  `@agentwatch_label` on the pane, and the most urgent of those on the window
- fires a desktop notification, if the pane is not already on screen
- refreshes the status line

Looking at a flagged pane clears it — a `waiting` pane drops back to `working`,
a `done` pane goes quiet.

If `$TMUX_PANE` is missing (agent launched outside tmux, wrapper scrubbed the
environment) the script walks the parent-PID chain looking for a pane tmux
recognises. If that also fails, `mark` is a silent no-op — an agent hook must
never break the agent.

## Commands

```
agentwatch mark <state> [msg]  Record a state transition (working|waiting|done|idle)
agentwatch seen [pane]         Acknowledge a pane, clearing its flag
agentwatch list                Show the roster, most urgent first
agentwatch status              Status-line summary string
agentwatch next                Jump to whoever has waited longest
agentwatch menu                Pick an agent from a tmux menu
agentwatch switch              Pick an agent with fzf
agentwatch goto <pane-id>      Jump to a specific pane
agentwatch reap                Drop records for panes that no longer exist
agentwatch hooks [--write]     Show or install the Claude Code hook config
agentwatch doctor              Diagnose the setup
```

## Default keybindings (TPM)

| Key | Action |
|-----|--------|
| `Alt+a` | Jump to the agent that has waited longest |
| `Alt+Shift+A` | Pick an agent from a menu |

Both are configurable. Set any key to `"none"` to disable it:

```tmux
set -g @agentwatch-next   "M-a"    # default
set -g @agentwatch-menu   "M-A"    # default
set -g @agentwatch-switch "none"   # fzf picker in a popup
set -g @agentwatch-list   "none"   # roster in a popup
```

## Status line

The plugin appends a glyph to `window-status-format` automatically, so flagged
windows stand out in the window list without any configuration. Turn it off with
`set -g @agentwatch-decorate-windows "off"`.

For a global count, add the summary to your status line:

```tmux
set -g status-right "#(agentwatch status) %H:%M"
```

It renders as `●2 ✔1 …3` — two agents want you, one just finished, three are
still working — and hides whichever counts are zero.

## Options

| Option | Default | Meaning |
|---|---|---|
| `@agentwatch-glyph-waiting` | `●` | Glyph for an agent waiting on you |
| `@agentwatch-glyph-done` | `✔` | Glyph for a finished agent |
| `@agentwatch-glyph-working` | `…` | Glyph for a busy agent |
| `@agentwatch-color-waiting` | `yellow` | Colour for `waiting` |
| `@agentwatch-color-done` | `green` | Colour for `done` |
| `@agentwatch-color-working` | `brightblack` | Colour for `working` |
| `@agentwatch-notify` | `auto` | `auto`, `on`, or `off` |
| `@agentwatch-notify-command` | — | Custom notifier; receives title, body, urgency as `$1 $2 $3` |
| `@agentwatch-done-threshold` | `30` | Skip the `done` notification for turns shorter than this many seconds |
| `@agentwatch-clear-on-focus` | `on` | Clear a pane's flag once you look at it |
| `@agentwatch-decorate-windows` | `on` | Append the glyph to `window-status-format` |
| `@agentwatch-status-show-working` | `on` | Include the `working` count in `agentwatch status` |

Notifications go through `notify-send` when it is available and fall back to
`tmux display-message`. A custom notifier overrides both:

```tmux
set -g @agentwatch-notify-command 'terminal-notifier -title "$1" -message "$2"'
```

## Other agents

Anything that can run a shell command on a state change works — just call
`agentwatch mark working|waiting|done` from its equivalent hook. Agents with no
hook system at all need output heuristics (`monitor-silence` plus a
`capture-pane` regex), which this plugin does not do.

## Requirements

- tmux 3.0 or newer (developed against 3.4)
- `jq` — only for `hooks --write` and for reading hook messages
- `fzf` — only for `switch`
- `notify-send` — only for desktop notifications

## Notes

- Storage lives in `$XDG_STATE_HOME/agentwatch` (`~/.local/state/agentwatch`).
  Override with `AGENTWATCH_DIR`. If you override it, set it for the tmux server
  too (`tmux set-environment -g AGENTWATCH_DIR ...`), otherwise hook-spawned
  helpers will not see the same files.
- Focus clearing needs `focus-events on`; the plugin sets it for you.
- Focus hooks are installed at hook index `90`, so re-sourcing the plugin
  replaces them instead of stacking duplicates.
- Records for dead panes are cleaned up whenever the roster is read.

## License

MIT
