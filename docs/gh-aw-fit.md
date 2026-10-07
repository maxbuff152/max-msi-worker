# gh-aw v0.90.3 fit assessment

Assessed 2026-10-07 against `origin/main` at `95dda43`.
Decision: defer gh-aw adoption; no runtime, workflow, queue, ledger, credentials,
or permissions are added by this change.

## Current ownership and evidence

`start-max-msi.sh` starts one isolated Cursor Linux worker in WSL using a tmux
session and the three roots from `msi-worker-dirs.sh`. Existing-session detection
prevents another local launch, but is not task arbitration. `msi-worker-status`
prints directory configuration; it does not report task acceptance or completion.
`BLOCKED.md` records September 11 status and still explicitly reserves four
human confirmations. It is historical evidence, not a current readiness probe.

The main tree has no `.github/workflows` surface, task queue, dispatch receiver,
or task receipt protocol. GitHub's workflow API does list the entrypoints check
introduced by open [PR #17](https://github.com/maxbuff152/max-msi-worker/pull/17);
that does not make it part of main. PR #17 owns the WSL launcher convergence;
this assessment does not duplicate that repair. Open PRs and issue #1 already
provide GitHub-native handoff records. No evidence establishes a lost or duplicate
GitHub-dispatched task in this repository.

## Comparison

| Responsibility | Current Max-MSI | gh-aw v0.90.3 | Fit |
| --- | --- | --- | --- |
| Execution | Cursor worker, local WSL, tmux, three repository roots | Compiled GitHub Actions agent jobs | Different runtime; no drop-in replacement |
| Admission | Avoid another tmux session | Git-backed work and claim replay | No inbound task adapter here |
| Completion | No task-level receipt in the visible source | Trusted worker context and safe-output finalization boundaries | Cursor does not emit this protocol |
| Durable state | GitHub PRs/issues plus dated status docs | Git-backed queue and typed ledger projections | Useful only with a fresh receipt producer |
| Model routing | Cursor account/runtime | Release routing feature specifically in the Copilot engine | Does not select Cursor's local model |
| Outputs | Local worker behavior | Agent read permissions, trusted safe-output writes | Cannot govern effects performed outside its boundary |

The October 3 release is marked **pre-release**. Its pinned coordination ADR is
**Draft** and explicitly distinguishes implemented snapshot queries from broader
mutation, worker-context, recovery and maintenance integration. Do not infer
full dispatch support from the October 5 post: that post also links PRs #65494
and #65443 under related work. Verify any future candidate against the exact
installed version, compiler and generated lock file.

## One bounded candidate: worker-readiness receipt history

The concrete gap is reconciling dated readiness claims in `BLOCKED.md` with
pending human confirmations and fresh machine evidence. A typed append-only
log could preserve **reported**, **machine-verified**, and **human-confirmed**
receipts without pretending the newest report proves all three. It must not
become a task queue or a second worker controller.

This is not yet a clear gh-aw win: this repository has no automated fresh
readiness producer, the missing confirmations require Maxwell, and issues plus
PR evidence already retain handoffs. An AI Actions run and new state branches
would add maintenance without obtaining the missing observations. First use
the existing issue/PR record and repair launcher checks through PR #17.

Revisit only when repeated readiness handoffs demonstrably lose evidence and
an existing trusted probe can produce sanitized receipts. Require:

- A receipt schema containing only a fixed worker ID, observation UTC time,
  source commit, evidence kind, result, and same-repository evidence link.
  No free-form commands, usernames, paths, credentials, contact or deal data.
- Machine observations cannot promote a human confirmation; stale or unavailable
  probes stay unknown. A test must enforce this distinction.
- Manual-only trigger, one run at a time, no AI retries or provider fallback,
  no self-hosted runner registration or worker start/restart.
- Agent permissions limited to required reads; allow only the named ledger's
  validated safe-output writes. No PR creation, comments, dispatch, merge,
  deployment, seller contact or business-record writes.
- Pin the compiler and actions, compile and inspect the lock file, and test
  malformed/stale/duplicate receipts and permission/output boundaries offline.
- Prove receipt projection across two authorized runs before calling it working.
  Establish engine authorization and cost limits separately; ChatGPT login does
  not prove that GitHub Actions inference is included.

No proof of concept is installed because the receipt producer and benefit are
not established. Rollback of this decision record is a normal Git revert; no
services or persistent ledger branches need cleanup.

## Primary sources (pinned where version behavior matters)

- [v0.90.3 release](https://github.com/github/gh-aw/releases/tag/v0.90.3)
- [October 5 weekly update](https://github.github.io/gh-aw/blog/2026-10-05-weekly-update/)
- [v0.90.3 coordination ADR](https://github.com/github/gh-aw/blob/v0.90.3/docs/adr/64955-git-backed-dispatch-work-coordination.md)
- [v0.90.3 built-in ledger smoke workflow](https://github.com/github/gh-aw/blob/v0.90.3/.github/workflows/smoke-builtin-ledgers.md)
- [v0.90.3 repo memory reference](https://github.com/github/gh-aw/blob/v0.90.3/docs/src/content/docs/reference/repo-memory.md)

Validation: inspected current main, launcher/status source, open PRs/issues,
GitHub workflow inventory, and exact-tag upstream ADR/example. Documentation-only
change: `git diff --check` and repository-relative link checks; no runtime test or
cloud inference run is warranted. Existing runtime and dirty main checkout remain
untouched.
