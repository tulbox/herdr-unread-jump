#!/usr/bin/env bash
# Focus the next herdr agent pane that needs attention.
# Tiers: blocked > done > idle (most recently finished first) > working.
# The first tier holding a pane other than the current one wins; repeated
# presses cycle within it. The current pane is never the target.
set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

AGENTS_JSON=$("$herdr_bin" agent list)

# The invoking client's pane; the server's `focused` flag may belong to
# another client, so it is the last resort.
CURRENT=$(jq -r '.focused_pane_id // empty' <<<"${HERDR_PLUGIN_CONTEXT_JSON:-}" 2>/dev/null || true)
CURRENT=${CURRENT:-${HERDR_PANE_ID:-}}
if [[ -z "$CURRENT" ]]; then
  CURRENT=$(jq -r '[.result.agents[] | select(.focused == true) | .pane_id][0] // empty' <<<"$AGENTS_JSON")
fi

# Pane ids for a tier, in cycle order.
tier_ids() {
  jq -r --arg tier "$1" '
    .result.agents as $a
    | if $tier == "blocked" then
        [$a[] | select(.agent_status == "blocked")] | sort_by(-(.state_change_seq // 0))
      elif $tier == "done" then
        [$a[] | select(.agent_status == "done")] | sort_by(-(.completion_seq // 0))
      elif $tier == "idle" then
        [$a[] | select(.agent_status == "idle" and (.completion_seq // 0) > 0)]
        | sort_by(-.completion_seq)
      else
        [$a[] | select(.agent_status == "working")]
      end
    | .[].pane_id
  ' <<<"$AGENTS_JSON"
}

TARGET=""
for tier in blocked done idle working; do
  IDS=()
  while IFS= read -r id; do
    [[ -n "$id" ]] && IDS+=("$id")
  done < <(tier_ids "$tier")
  ((${#IDS[@]} > 0)) || continue

  # Step past the current pane if it sits in this tier; else take the first.
  NEXT=0
  for i in "${!IDS[@]}"; do
    if [[ "${IDS[$i]}" == "$CURRENT" ]]; then
      NEXT=$(( (i + 1) % ${#IDS[@]} ))
      break
    fi
  done
  if [[ "${IDS[$NEXT]}" != "$CURRENT" ]]; then
    TARGET=${IDS[$NEXT]}
    break
  fi
done

if [[ -z "$TARGET" ]]; then
  echo "herdr-unread: no other agent pane needs attention" >&2
  "$herdr_bin" notification show "No agents need attention" \
    --body "Nothing blocked, done, finished, or working elsewhere." --sound none >/dev/null 2>&1 || true
  exit 1
fi

"$herdr_bin" agent focus "$TARGET" >/dev/null
echo "herdr-unread: focused $TARGET ($tier)"
