#!/usr/bin/env bash
# Focus the next herdr agent pane that needs attention.
# Priority: blocked > done > working. Repeatedly running cycles
# within the prioritized group.
set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

AGENTS_JSON=$("$herdr_bin" agent list)

PANE_IDS=()
for status in blocked done working; do
  PANE_IDS=()
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    PANE_IDS+=("$id")
  done < <(
    jq -r --arg status "$status" '
      .result.agents[]
      | select(.agent_status == $status)
      | .name // .pane_id
    ' <<<"$AGENTS_JSON"
  )
  if ((${#PANE_IDS[@]} > 0)); then
    break
  fi
done

if ((${#PANE_IDS[@]} == 0)); then
  echo "herdr-unread: no blocked, unread, or working agent panes" >&2
  "$herdr_bin" notification show "No agents need attention" \
    --body "Nothing blocked, unread, or working." --sound none >/dev/null 2>&1 || true
  exit 1
fi

CURRENT=$(jq -r '.result.agents[] | select(.focused == true) | .name // .pane_id' <<<"$AGENTS_JSON")

NEXT_INDEX=0
for i in "${!PANE_IDS[@]}"; do
  if [[ "${PANE_IDS[$i]}" == "$CURRENT" ]]; then
    NEXT_INDEX=$(( (i + 1) % ${#PANE_IDS[@]} ))
    break
  fi
done

TARGET=${PANE_IDS[$NEXT_INDEX]}
"$herdr_bin" agent focus "$TARGET" >/dev/null
echo "herdr-unread: focused $TARGET ($status $((NEXT_INDEX + 1))/${#PANE_IDS[@]})"
