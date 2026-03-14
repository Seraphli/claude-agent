# /ca:execute — Execute Confirmed Plan

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `plan_confirmed: true` from the parsed JSON. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

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

Read `model_profile` and `ca-executor_model` from the config JSON already loaded.
Resolve model: `ca-executor_model` override → `model_profile` via `~/.claude/ca/references/model-profiles.md`. Pass to Task tool.

### 3. Parse execution order

Parse `## Implementation Steps` in PLAN.md: ordered = sequential, unordered = parallel, nested = recursive. For each leaf item, find its `## Step Details` entry to pass to the executor.

### 3a. Sequential execution

Launch a single `ca-executor` with step details inlined. Wait for completion before next item.

### 3b. Parallel execution

Read `max_concurrency` from the config JSON already loaded. If items exceed limit, split into batches. Launch multiple `ca-executor` agents **in the same message**, each receiving:
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

Also set `status_note` to a context-aware summary of what was executed, e.g.: "Executed: <brief description of changes made>. Ready for verification."

### 7. Update codebase map

If `.ca/map.md` exists: update to reflect changes, update date.
If missing (empty project): create via `/ca:map`.

### 7b. Auto-commit on branch (if enabled)

Read `use_branches` from the config JSON already loaded.
Read STATUS.md for `branch_name`.

If `use_branches` is `true` AND `branch_name` exists in STATUS.md:
1. Verify current git branch matches `branch_name`: `git branch --show-current`. If mismatch, warn user and skip commit.
2. Check for changes: `git status --porcelain`. If no changes, skip.
3. Stage all changes: `git add -A`.
4. Read BRIEF.md first line (after `# Brief`) for title.
5. Commit: `git commit -m "wip: <brief title>"`.

### 8. Auto-proceed to verification

If `batch_mode: true`: do NOT auto-proceed. Tell user execution is complete and stop.

Otherwise check `auto_proceed_to_verify` from the config JSON:
- `true`: Tell user complete, execute `Skill(ca:verify)`.
- `false`/not set: Suggest next steps:
  - `/ca:verify` (or `/ca:next`)
  - `/clear` to free context
  - Tip: set `auto_proceed_to_verify: true` in `/ca:settings`

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
