# herdr-unread-jump

Jump to the next Herdr agent pane that needs attention.

1. List agents via `herdr agent list`
2. Prefer `agent_status == "blocked"`, else `"done"`
3. Focus the next pane in that group (wraps around)

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
