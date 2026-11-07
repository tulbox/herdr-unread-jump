# herdr-unread-jump

Jump to the next Herdr agent pane that needs attention.

1. List agents via `herdr agent list`.
2. Tiers: `blocked`, then `done`, then `idle` agents that have finished a turn (most recent `completion_seq` first), then `working`.
3. Take the first tier holding a pane other than the invoking one; repeated presses cycle within it. The current pane is never the target.
4. Nothing matches: show a Herdr notification and exit 1.

The `idle` tier exists because the server marks a completion seen once focused, so most finished agents report `idle`, not `done`; Done badges in the TUI are tracked per client.

## Tests

```bash
bash tests/next_test.sh
```

## Requirements

- [Herdr](https://herdr.dev/) `>= 0.7.5`
- [`jq`](https://jqlang.github.io/jq/)

## Install

Install the plugin from GitHub:

```bash
herdr plugin install to4iki/herdr-unread-jump
```

Add a keybinding to your Herdr config:

```toml
[[keys.command]]
key = "prefix+u"
type = "plugin_action"
command = "to4iki.unread-jump.next"
description = "focus next unread agent"
```

Reload Herdr:

```bash
herdr server reload-config
```

Then press `prefix+u` to jump to the next unread agent.

## Development

```bash
herdr plugin link .
```

## License

MIT
