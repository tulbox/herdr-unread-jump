#!/usr/bin/env bash
# Runs next.sh against a fake herdr binary. Usage: bash tests/next_test.sh
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)

cat >"$TMP/herdr" <<'FAKE'
#!/usr/bin/env bash
case "$1 $2" in
  "agent list") cat "$FAKE_AGENTS" ;;
  "agent focus") echo "$3" >"$FAKE_FOCUSED" ;;
  "notification show") ;;
esac
FAKE
chmod +x "$TMP/herdr"
export HERDR_BIN_PATH="$TMP/herdr"

fail=0
n=0
# agents: JSON array of agent objects. expect: pane id, or "none" for exit 1.
check() {
  local name=$1 current=$2 agents=$3 expect=$4 got
  n=$((n + 1))
  export FAKE_AGENTS="$TMP/agents-$n.json" FAKE_FOCUSED="$TMP/focused-$n"
  echo "{\"result\":{\"agents\":$agents}}" >"$FAKE_AGENTS"
  if HERDR_PLUGIN_CONTEXT_JSON="{\"focused_pane_id\":\"$current\"}" bash "$ROOT/next.sh" >/dev/null 2>&1; then
    got=$(cat "$FAKE_FOCUSED")
  else
    got=none
  fi
  if [[ "$got" == "$expect" ]]; then echo "ok   $name"; else echo "FAIL $name: want $expect, got $got"; fail=1; fi
}

# a <pane_id> <status> [completion_seq] [state_change_seq] [focused]
a() { printf '{"pane_id":"%s","agent_status":"%s","completion_seq":%s,"state_change_seq":%s,"focused":%s}' "$1" "$2" "${3:-0}" "${4:-0}" "${5:-false}"; }

check "blocked beats everything" p1 "[$(a p1 working),$(a p2 done 9),$(a p3 blocked)]" p3
check "done beats idle" p1 "[$(a p1 idle 5),$(a p2 idle 9),$(a p3 done 1)]" p3
check "idle picks most recent completion" p1 "[$(a p1 working),$(a p2 idle 3),$(a p3 idle 8),$(a p4 idle 0)]" p3
check "idle cycles to next most recent" p3 "[$(a p2 idle 3),$(a p3 idle 8),$(a p5 idle 5)]" p5
check "idle skips never-finished agents" p1 "[$(a p1 working),$(a p4 idle 0),$(a p5 working)]" p5
check "working never picks current pane" p1 "[$(a p1 working),$(a p2 working)]" p2
check "only current pane -> none" p1 "[$(a p1 working)]" none
check "tier holding only current falls through" p1 "[$(a p1 blocked),$(a p2 idle 4)]" p2
check "context beats server focused flag" p2 "[$(a p1 done 1 0 true),$(a p2 done 2)]" p1
check "no agents -> none" p1 "[]" none
check "idle falls back to state_change_seq" p1 "[$(a p1 working),{\"pane_id\":\"p2\",\"agent_status\":\"idle\",\"state_change_seq\":3},{\"pane_id\":\"p3\",\"agent_status\":\"idle\",\"state_change_seq\":7}]" p3

exit $fail
