# Desk DJ consolidation

Desk DJ is extracted onto main without PR #13's worker parking or PR #15's
fleet status. This is source reconciliation, not a Linux music port or activation.

## Preserved commands and behavior

On the original MSI WSL/Windows setup:
`bash bin/desk-dj.sh now|start|stop|status|rotate|install-schedule|uninstall-schedule`.

Daily Windows schedule: start 09:00; rotate 11:00, 13:00, 15:00, 17:00;
stop 19:00. Tasks and rotation use Windows local time. The America/Chicago
config field does not implement timezone conversion.

Weighted selection excludes all instances of the last URI when another is
available; a sole URI can repeat. Every start and in-window rotate unmutes and
sets Windows master volume to 25% before playback, checking HRESULTs and readback.
Explicit start remains allowed outside the window; rotate returns outside it.
The inherited start log misleadingly says "skipped" although manual start proceeds.

The inherited wrapper copies script/config on every invocation, including status.
It requires original Windows C: paths and PowerShell; do not use it as a native
Linux probe or over an unreviewed custom installed config.

## Exact drift inspected 2026-10-07

- main: `95dda4381450e340cf20cf80cb308798fb05c830`
- PR #14: `6929cab324f50718a465b5029c5db10cf3e53cf0`
- PR #16: `9286199cdd0a06aa649495e1ad0f77d0cff82a30`

The Windows installation was read through the read-only mount:
`/media/max/Windows/Users/maxwe/AppData/Local/Maxwell/DeskDJ/`.
Installed Invoke-DeskDJ.ps1 is byte-identical to PR #16 and this branch.
SHA-256: `e05d47e52aa5566f3afb39cf6fc09219e826125eb941282733873d231d1adbf1`.

Installed config differs from PR #16. This branch preserves its parsed JSON
exactly; only formatting differs.

| Source ID | PR #16 weight | Installed/preserved weight |
| --- | ---: | ---: |
| deebaby-hardest | 5 | 6 |
| deebaby-mix-fire | 4 | 5 |
| drake-wayne-search | 2 | 1 |
| logan-orbit-artists | 3 | 1 |
| rapcaviar | 1 | 5 |
| get-turnt | absent | 4 |
| beast-mode | absent | 3 |

New URIs: Get Turnt `spotify:playlist:37i9dQZF1DWY4xHQpAvur6`;
Beast Mode `spotify:playlist:37i9dQZF1DX76Wlfdnj7AP`.
The added installed note attributes this to a September 23 request for more
upbeat music; it is installation evidence, not a new approval.

PR #16 config SHA-256:
`ef738e9c0c1661f86f6c11247c84d567e8aed7ad7a964c8d03cf2bb7bba184dc`.
Installed config SHA-256:
`ab77969b5c8832a464934ea01bd52a0a282bed5a8cb1ed277efb68b176d413b9`.

All six installed SFHS-DeskDJ task XML definitions match the daily action/times
and installed script path, with interactive token and least privilege.
Latest inspected logs are September 23: successful play and unmuted 25% volume;
the final stop had no Spotify session. These are historical Windows receipts,
not evidence of current Linux playback.

Installed force-hardest.ps1, force-upbeat.ps1 and nudge-hardest.ps1 are one-off
helpers unused by the schedule and left untouched. The old queue-plan.json is
a date-specific advisory snapshot never read by the script; it is excluded.
State, logs and Spotify credentials are not committed.

## Validation and rollback

Run `bash scripts/test-desk-dj.sh` with Bash and PowerShell (`pwsh`) available.
Tests parse production PowerShell and load function definitions only, mocking
external operations. They exercise weighting, duplicate-URI exclusion,
single-source/empty-pool fallback, window boundaries, six task arguments,
volume fallback/clamping, and start/rotate config propagation.
Tests never start Spotify, touch live state, or modify scheduler/volume.

Script bytes match the inspected installation; config semantics match it.
No live Windows installation, Linux timer, audio setting or worker was changed.
COM/SMTC hardware behavior was not re-tested under Linux.
Rollback is closing this PR or reverting its consolidation commit after merge.
