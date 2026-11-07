# Runs next.ps1 against a fake herdr script. Usage: powershell -File tests/next_test.ps1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("unread-jump-test-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null

$fake = Join-Path $tmp 'herdr.ps1'
@'
switch ("$($args[0]) $($args[1])") {
  'agent list'  { Get-Content -Raw $env:FAKE_AGENTS }
  'agent focus' { Set-Content $env:FAKE_FOCUSED $args[2] }
}
'@ | Set-Content $fake
$env:HERDR_BIN_PATH = $fake

$script:fail = 0
$script:n = 0
# agents: array of agent hashtables. expect: pane id, or 'none' for exit 1.
function Check($name, $current, $agents, $expect) {
  $script:n++
  $env:FAKE_AGENTS = Join-Path $tmp "agents-$script:n.json"
  $env:FAKE_FOCUSED = Join-Path $tmp "focused-$script:n"
  ConvertTo-Json -Depth 5 @{ result = @{ agents = @($agents) } } | Set-Content $env:FAKE_AGENTS
  $env:HERDR_PLUGIN_CONTEXT_JSON = "{`"focused_pane_id`":`"$current`"}"
  $shell = (Get-Process -Id $PID).Path
  $ErrorActionPreference = 'Continue'  # 5.1 turns child stderr into a terminating error under Stop
  & $shell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'next.ps1') *> $null
  $got = if ($LASTEXITCODE -eq 0) { (Get-Content $env:FAKE_FOCUSED).Trim() } else { 'none' }
  if ($got -eq $expect) { "ok   $name" } else { "FAIL ${name}: want $expect, got $got"; $script:fail = 1 }
}

# A <pane_id> <status> [completion_seq] [state_change_seq] [focused]
function A($id, $status, $cseq = 0, $sseq = 0, $focused = $false) {
  @{ pane_id = $id; agent_status = $status; completion_seq = $cseq; state_change_seq = $sseq; focused = $focused }
}

Check 'blocked beats everything' p1 @((A p1 working), (A p2 done 9), (A p3 blocked)) p3
Check 'done beats idle' p1 @((A p1 idle 5), (A p2 idle 9), (A p3 done 1)) p3
Check 'idle picks most recent completion' p1 @((A p1 working), (A p2 idle 3), (A p3 idle 8), (A p4 idle 0)) p3
Check 'idle cycles to next most recent' p3 @((A p2 idle 3), (A p3 idle 8), (A p5 idle 5)) p5
Check 'idle skips never-finished agents' p1 @((A p1 working), (A p4 idle 0), (A p5 working)) p5
Check 'working never picks current pane' p1 @((A p1 working), (A p2 working)) p2
Check 'only current pane -> none' p1 @((A p1 working)) none
Check 'tier holding only current falls through' p1 @((A p1 blocked), (A p2 idle 4)) p2
Check 'context beats server focused flag' p2 @((A p1 done 1 0 $true), (A p2 done 2)) p1
Check 'no agents -> none' p1 @() none
Check 'idle falls back to state_change_seq' p1 @((A p1 working), @{ pane_id = 'p2'; agent_status = 'idle'; state_change_seq = 3 }, @{ pane_id = 'p3'; agent_status = 'idle'; state_change_seq = 7 }) p3

exit $script:fail
