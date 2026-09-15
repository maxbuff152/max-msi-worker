# Phone → MSI

Account: `info@sellersfirsthomesolutions.com`  
Runtime: **My Machines** (never Cloud).

## Pick this

| Want to work on… | Pick this |
|------------------|-----------|
| Anything on the MSI brain (site, infra, messages) | **MSI** |

One WSL brain worker. One Runtime row for new work.

**Compat alias:** **Max-MSI** may also appear (same machine/roots). It exists only so older Grok Bot / sand schedules that still target `Max-MSI` stop failing with “Unable To Complete Request.” Prefer **MSI** for anything new.

## Durability
- Logon autostart: Windows task `Cursor-Max-MSI-WSL-Worker`
- Self-heal every ~10 min: `Cursor-Max-MSI-WSL-Worker-Watcher` → `repair-max-msi.sh`
- Windows Cursor worker under `D:\CODEX SPINE…` is **parked** (specs moved aside) — do not revive it as a second MSI brain
- Old Cloudflare Site / Remote Bridge stays **Disabled**

## Grok Bot / sand clocks
Stuck schedules that spawned ERROR agents (iMessage ROWID poll, Max-MSI up/down probe, weekday health) were archived. Keep Grok Bot clocks that spawn private-worker Cursor agents **parked** unless retargeted to **MSI** (or Mac for iMessage). Glass Automation keepers: Slack Digest only.

## Mac (iMessage lane)
Mac worker name: **Mac**. If `agent whoami` says keychain locked over SSH, unlock once at the Mac keyboard:
`security unlock-keychain ~/Library/Keychains/login.keychain-db`
Then confirm the Mac worker is signed into **info@…** (same account as MSI).

## Fleet proof (optional)
```
On MSI: ssh macbook with echo MAC_OK and hostname, then ssh logan with echo LENOVO_OK and hostname. Report both. Do not sign those PCs out of Cursor.
```
