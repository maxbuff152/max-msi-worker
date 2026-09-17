# Agent brain trim (2026-09-17)

Maxwell asked to look at the whole system because “the more we add, the worse it gets.”

## What we kept
- 3 PCs (MSI / Lenovo / Mac)
- 3 git homes (website / max-msi-worker / messages-loop)
- Google + iMessage simple stack

## What we cut (local + memory)
- Always-on user rules **15 → 9**
- Stale memory receipts → `~/.cursor/memory/archive/2026-09-17-trim/`
- Per-repo ECC skill clones (~9MB) removed
- Per-repo ECC language rule dumps (Angular/C++/…) removed; website keeps `sfhs-*.mdc` only

## Obsidian / AI database
**Deferred.** Problem was overload, not missing search. Revisit only if a real recall miss is measured after this trim.

## Do not
- Re-run full ECC install into every repo
- Add always-on rules without retiring one
- Treat soft-board PR streaks as progress

Canon for agents: `~/.cursor/memory/simple-operating-model.md`
