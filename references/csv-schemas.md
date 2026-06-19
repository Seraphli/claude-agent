# CSV Schemas (TASKS.csv / VERIFY.csv)

All reads/updates go through `scripts/ca-csv.js`. The orchestrator is the SINGLE writer to TASKS.csv (executors return results; the orchestrator writes). All enum values are English; display layers may localize for presentation only.

## TASKS.csv — per-round execution ledger
Location: `rounds/N/TASKS.csv` (round 0 = `rounds/0/TASKS.csv`). Mirrors that round's PLAN.md. Replaces PLAN.md's "Implementation Steps".
Columns: `id` (per-round local int), `phase` (same phase = parallel, different phase number = sequential), `title`, `description`, `verify_refs` (space-separated STABLE VERIFY.csv ids this task addresses; may be empty), `dev` (`pending`/`done` — code written), `git` (`pending`/`done`/`skipped` — commit state), `notes`.

`git` lifecycle: in worktree mode and instant, `git`→`done` at the execute-time wip commit. In non-worktree standard/quick/write (no execute-time commit), `git` stays `pending` through execute and flips at finish (or `skipped` if that flow never commits at task level). `git` tracks commit state ONLY — task completion = `dev`=done plus its criteria passing, independent of `git`.

## VERIFY.csv — cross-round verification ledger
Location: workflow root `VERIFY.csv` (single, cross-round). Mirrors CRITERIA.md; REPLACES it.
Columns: `id` (STABLE, `v1`/`v2`…, referenced by TASKS.csv `verify_refs`; APPEND-ONLY, never reused), `type` (`self_check` / `test`), `method` (`auto` / `manual`), `criterion` (action + assertion), `result` (`pass`/`fail`/`pending` — latest valid result), `last_verified_round` (which round produced the current `result`), `notes`.

Two types classify each criterion by HOW it is verified: `self_check` = confirmable by static inspection of the code/files (read/grep, no execution); `test` = requires running code/tests to confirm. The type is a per-criterion label on the task's real acceptance conditions — there is NO fixed/boilerplate `self_check` set added to every workflow.

Re-verify model: `auto` criteria are re-verified in FULL every round (regression safety) → refresh `result` + `last_verified_round`. `manual` `pending`/`fail` MUST be verified; a `manual` already holding `pass` MAY retain its last valid result in an auto-fix round (its `last_verified_round` shows when it was actually verified). No-false-green: a `manual` row that is `pending`/`fail` must never let the workflow complete via the auto-fix path. Criteria grow across rounds (append-only) as ISSUES surface new acceptance conditions.

## ca-csv.js usage
- `init-tasks --file rounds/N/TASKS.csv` / `init-verify --file VERIFY.csv`
- `add-task --file rounds/N/TASKS.csv --phase P --title T --description D [--verify-refs "v1 v2" --verify-file VERIFY.csv] [--notes X]`
- `add-criterion --file VERIFY.csv --type self_check|test --method auto|manual --criterion C [--notes X]`
- `update --file F --id ID --field COL --value V` (rejects `--field id`; validates enums)
- `get --file F [--id ID] [--json]`
