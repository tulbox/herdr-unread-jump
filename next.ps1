# Windows port of next.sh; same tiers and cycling. PowerShell 5.1+, no jq.
$ErrorActionPreference = 'Stop'

$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr' }

$agents = @((& $herdr agent list | Out-String | ConvertFrom-Json).result.agents)

# The invoking client's pane; the server's `focused` flag may belong to
# another client, so it is the last resort.
$current = $null
if ($env:HERDR_PLUGIN_CONTEXT_JSON) {
  $current = ($env:HERDR_PLUGIN_CONTEXT_JSON | ConvertFrom-Json).focused_pane_id
}
if (-not $current) { $current = $env:HERDR_PANE_ID }
if (-not $current) { $current = ($agents | Where-Object { $_.focused } | Select-Object -First 1).pane_id }

function Seq($agent, $field) { if ($agent.$field) { [long]$agent.$field } else { 0 } }

# Pane ids for a tier, in cycle order.
function Get-TierIds($tier) {
  $picked = switch ($tier) {
    'blocked' { $agents | Where-Object { $_.agent_status -eq 'blocked' } | Sort-Object { Seq $_ 'state_change_seq' } -Descending }
    'done'    { $agents | Where-Object { $_.agent_status -eq 'done' } | Sort-Object { Seq $_ 'completion_seq' } -Descending }
    'idle'    { $agents | Where-Object { $_.agent_status -eq 'idle' -and (Seq $_ 'completion_seq') -gt 0 } | Sort-Object { Seq $_ 'completion_seq' } -Descending }
    'working' { $agents | Where-Object { $_.agent_status -eq 'working' } }
  }
  @($picked | ForEach-Object { $_.pane_id })
}

$target = $null
foreach ($tier in 'blocked', 'done', 'idle', 'working') {
  $ids = @(Get-TierIds $tier)  # @() keeps a one-element result an array
  if ($ids.Count -eq 0) { continue }
  # Step past the current pane if it sits in this tier; else take the first.
  $i = [array]::IndexOf($ids, $current)
  $next = if ($i -ge 0) { ($i + 1) % $ids.Count } else { 0 }
  if ($ids[$next] -ne $current) { $target = $ids[$next]; break }
}

if (-not $target) {
  [Console]::Error.WriteLine('herdr-unread: no other agent pane needs attention')
  try {
    & $herdr notification show 'No agents need attention' --body 'Nothing blocked, done, finished, or working elsewhere.' --sound none *> $null
  } catch {}
  exit 1
}

& $herdr agent focus $target > $null
"herdr-unread: focused $target ($tier)"
