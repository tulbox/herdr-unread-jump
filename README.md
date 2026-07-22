# herdr-unread-jump

Focus the next Herdr agent pane that needs attention. Agents in `blocked`
take priority over `done`. Running the action repeatedly cycles within the
prioritized group.

## Requirements

- [Herdr](https://herdr.dev/) `>= 0.7.0`
- [`jq`](https://jqlang.github.io/jq/)

## Install

Local development:

```sh
herdr plugin link .
```

From GitHub once published:

```sh
herdr plugin install to4iki/herdr-unread-jump
```

## Keybinding

Bind the action in `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+u"
type = "plugin_action"
command = "to4iki.unread-jump.next"
description = "focus next unread agent"
```

Invoke manually:

```sh
herdr plugin action invoke to4iki.unread-jump.next
```

## Behavior

1. List agents via `herdr agent list`
2. Prefer panes with `agent_status == "blocked"`, else `"done"`
3. Focus the next pane in that group (wraps around)
