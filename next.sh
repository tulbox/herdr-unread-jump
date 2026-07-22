#!/usr/bin/env bash
# Focus the next herdr agent pane that needs attention.
# "blocked" takes priority over "done". Repeatedly running cycles
# within the prioritized group.
set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

if ! command -v jq >/dev/null 2>&1; then
  echo "unread-jump: jq is required" >&2
  exit 1
fi

agents_json=$("$herdr_bin" agent list)

pane_ids=()
status=""
for candidate in blocked done; do
  pane_ids=()
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    pane_ids+=("$id")
  done < <(
    jq -r --arg status "$candidate" '
      .result.agents[]
      | select(.agent_status == $status)
      | .name // .pane_id
    ' <<<"$agents_json"
  )
  if ((${#pane_ids[@]} > 0)); then
    status=$candidate
    break
  fi
done

if ((${#pane_ids[@]} == 0)); then
  echo "unread-jump: no blocked or unread agent panes" >&2
  exit 1
fi

current=$(jq -r '
  .result.agents[]
  | select(.focused == true)
  | .name // .pane_id
' <<<"$agents_json")

next_index=0
for i in "${!pane_ids[@]}"; do
  if [[ "${pane_ids[$i]}" == "$current" ]]; then
    next_index=$(( (i + 1) % ${#pane_ids[@]} ))
    break
  fi
done

target=${pane_ids[$next_index]}
"$herdr_bin" agent focus "$target" >/dev/null
echo "unread-jump: focused $target ($status $((next_index + 1))/${#pane_ids[@]})"
