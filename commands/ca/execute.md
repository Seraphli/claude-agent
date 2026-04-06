---
name: ca-execute
description: Executes the confirmed implementation plan using isolated executor agents. Use when a plan has been triple-confirmed.
---

# /ca:execute — Execute Confirmed Plan

**CRITICAL — Code Modification Policy**: This command delegates code modifications to ca-executor agents. The orchestrator itself does NOT modify code directly.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `plan_confirmed: true` from the parsed JSON. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

### 0. Task cleanup and initialization

1. Call `TaskList` to get all existing tasks.
2. If no tasks exist, skip to step 5.
3. If ALL tasks are `completed`: call `TaskUpdate` with `status: "deleted"` for each task.
4. If any task is NOT `completed` (pending or in_progress):
   a. Call `TaskGet` for each uncompleted task.
   b. Analyze possible causes by cross-referencing with STATUS.md (e.g., session interrupted, phase skipped, abnormal exit).
   c. Present to user: list each uncompleted task with subject, status, and possible cause.
   d. `AskUserQuestion`: header "Tasks", question "There are uncompleted tasks from the previous phase. How to proceed?", options:
      - "Clear and continue" — "Delete all old tasks and start current phase"
      - "Stop" — "Pause to investigate the previous phase's issues"
   e. If "Clear and continue": call `TaskUpdate` with `status: "deleted"` for ALL tasks.
   f. If "Stop": stop current command immediately.
5. Create initial tasks:
   - `TaskCreate`: subject "Prepare execution", activeForm "Preparing execution"
   - `TaskCreate`: subject "Write SUMMARY.md", activeForm "Writing summary"
   - `TaskCreate`: subject "Commit & update map", activeForm "Committing and updating map"

Mark "Prepare execution" as `in_progress`.

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

**CRITICAL — Do NOT skip this step.** Check if `.ca/map.md` exists:

1. Run: `ls <project-root>/.ca/map.md 2>/dev/null` to check existence.
2. If the file does NOT exist AND the project is not empty (has source files): scan the project structure yourself using Glob/Read tools and write `.ca/map.md` directly. **Do NOT use `Skill(ca:map)` — Skill calls will terminate the current session.** Write a basic map with directory structure and key files.
3. If the project is empty (no source files): skip (map will be created in step 7).

Mark "Prepare execution" as `completed`.

### 2. Resolve model for ca-executor

Read `ca-executor_model` from the config JSON already loaded. This is the already-resolved model name (opus/sonnet/haiku). Pass to Task tool.

### 3. Parse execution order

Parse `## Implementation Steps` in PLAN.md: ordered = sequential, unordered = parallel, nested = recursive. For each leaf item, find its `## Step Details` entry to pass to the executor.

For each leaf item in the Implementation Steps outline, `TaskCreate`: subject "Step N: <step title from plan>", activeForm "Executing step N: <title>".

### 3a. Sequential execution

Mark the corresponding "Step N: <title>" task as `in_progress`.
Launch a single `ca-executor` with step details inlined. Wait for completion before next item.
After executor completes: mark as `completed`.

### 3b. Parallel execution

Read `max_concurrency` from the config JSON already loaded. If items exceed limit, split into batches. Mark all tasks in the current batch as `in_progress`. Launch multiple `ca-executor` agents **in the same message**, each receiving:
- Step details inlined
- REQUIREMENT.md/BRIEF.md content
- Project root path
- Output file: `SUMMARY-executor-{N}.md`

Wait for all to complete before next sequential item. As each executor completes: mark the corresponding task as `completed`.

### 4. Write SUMMARY.md

Mark "Write SUMMARY.md" as `in_progress`.

- **Single mode**: Write agent's summary to SUMMARY.md.
- **Parallel mode**: Merge all `SUMMARY-executor-*.md` into SUMMARY.md, delete individual files.

If fix_round > 0, write to `.ca/workflows/<active_id>/rounds/<N>/SUMMARY.md`.

Mark "Write SUMMARY.md" as `completed`. Mark "Commit & update map" as `in_progress`.

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

If `.ca/map.md` exists: update it directly using Read/Write tools to reflect changes and update the date.
If missing (empty project): create it directly using Glob/Read/Write tools. **Do NOT use `Skill(ca:map)` — Skill calls will terminate the current session.**

### 7b. Auto-commit on branch (if enabled)

Read `use_branches` from the config JSON already loaded.
Read STATUS.md for `branch_name`.

If `use_branches` is `true` AND `branch_name` exists in STATUS.md:
1. Verify current git branch matches `branch_name`: `git branch --show-current`. If mismatch, warn user and skip commit.
2. Check for changes: `git status --porcelain`. If no changes, skip.
3. Stage all changes: `git add -A`.
4. Read BRIEF.md first line (after `# Brief`) for title.
5. Commit: `git commit -m "wip: <brief title>"`.

Mark "Commit & update map" as `completed`.

### 8. Auto-proceed to verification

If `batch_mode: true`: do NOT auto-proceed. Tell user execution is complete and stop.

If `auto_fix_mode: true` in STATUS.md: Tell user auto-fix execution complete, execute `Skill(ca:verify)`.

Otherwise check `auto_proceed_to_verify` from the config JSON:
- `true`: Tell user complete, execute `Skill(ca:verify)`.
- `false`/not set: Suggest next steps:
  - `/ca:verify` (or `/ca:next`)
  - `/clear` to free context
  - Tip: set `auto_proceed_to_verify: true` in `/ca:settings`

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
