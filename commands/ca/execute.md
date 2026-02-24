# /ca:execute — Execute Confirmed Plan

Read `~/.claude/ca/config.md` (global) then `.ca/config.md` (workspace override).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `plan_confirmed: true`. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

## Behavior

You are the execution orchestrator. You delegate the actual work to the `ca-executor` agent running in the foreground.

### 1. Read context

Read these files and collect their full content:
- `.ca/workflows/<active_id>/PLAN.md`
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick`)

Read `fix_round` from STATUS.md (default: 0).
If `fix_round` > 0 (fix round N):
- Read PLAN.md from `.ca/workflows/<active_id>/rounds/<N>/PLAN.md`

### 1b. Ensure codebase map exists

If `.ca/map.md` missing and project is not empty: run `/ca:map` first. If empty project: skip (created in step 7).

### 2. Resolve model for ca-executor

Resolve model: `ca-executor_model` override → `model_profile` (default: `balanced`) via `~/.claude/ca/references/model-profiles.md`. Pass to Task tool.

### 3. Parse execution order

Parse `## Implementation Steps` in PLAN.md: ordered = sequential, unordered = parallel, nested = recursive. For each leaf item, find its `## Step Details` entry to pass to the executor.

### 3a. Sequential execution

Launch a single `ca-executor` with step details inlined. Wait for completion before next item.

### 3b. Parallel execution

Read `max_concurrency` from config (default: `4`). If items exceed limit, split into batches. Launch multiple `ca-executor` agents **in the same message**, each receiving:
- Step details inlined
- REQUIREMENT.md/BRIEF.md content
- Project root path
- Output file: `SUMMARY-executor-{N}.md`

Wait for all to complete before next sequential item.

### 4. Write SUMMARY.md

- **Single mode**: Write agent's summary to SUMMARY.md.
- **Parallel mode**: Merge all `SUMMARY-executor-*.md` into SUMMARY.md, delete individual files.

If fix_round > 0, write to `.ca/workflows/<active_id>/rounds/<N>/SUMMARY.md`.

### 5. Present execution summary

Display to the user:

```
## Execution Summary

### Changes Made
- file1.py — what changed
- file2.py — what changed

### Steps Completed
1. ...
2. ...

### Notes/Deviations (if any)
- ...
```

### 6. Update STATUS.md

Set `execute_completed: true`, `current_step: execute`.

### 7. Update codebase map

If `.ca/map.md` exists: update to reflect changes, update date.
If missing (empty project): create via `/ca:map`.

### 8. Auto-proceed to verification

If `batch_mode: true`: do NOT auto-proceed. Tell user execution is complete and stop.

Otherwise check `auto_proceed_to_verify`:
- `true`: Tell user complete, execute `Skill(ca:verify)`.
- `false`/not set: Suggest next steps:
  - `/ca:verify` (or `/ca:next`)
  - `/clear` to free context
  - Tip: set `auto_proceed_to_verify: true` in `/ca:settings`

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
