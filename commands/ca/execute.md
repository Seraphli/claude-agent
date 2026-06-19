---
name: ca-execute
description: Executes the confirmed implementation plan using isolated executor agents. Use when a plan has been confirmed (triple or single confirmation).
---

# /ca:execute — Execute Confirmed Plan

**CRITICAL — Code Modification Policy**: This command delegates code modifications to ca-executor agents. The orchestrator itself does NOT modify code directly.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

### Resolve workflow ID

Determine which workflow to operate on using this priority:

1. **Context inference**: If the current conversation has already been working with a specific workflow (e.g., you just ran `/ca:quick` or `/ca:plan` for it earlier in this session), use that workflow ID.
2. **Single workflow**: Run `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. If exactly one workflow exists, use it automatically.
3. **Multiple workflows**: If multiple workflows exist, present them to the user and ask which one to operate on:
   - `AskUserQuestion`: header "[W.Workflow]", question "Which workflow do you want to execute?", options: list each workflow (label: workflow ID, description: "<workflow_type>, step: <current_step>")
4. **No workflows**: If no workflows exist, tell the user to run `/ca:new` or `/ca:quick` first and stop.

After resolving `<active_id>`:

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root> --workflow-id <active_id>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `plan_confirmed: true` from the parsed JSON. If not, tell the user to run `/ca:plan` first and get the plan confirmed. **Stop immediately.**

### 0. Task cleanup and initialization

1. Call `TaskList` to get all existing tasks.
2. If no tasks exist, skip to step 5.
3. If ALL tasks are `completed`: call `TaskUpdate` with `status: "deleted"` for each task.
4. If any task is NOT `completed` (pending or in_progress):
   a. Call `TaskGet` for each uncompleted task.
   b. Analyze possible causes by cross-referencing with STATUS.md (e.g., session interrupted, phase skipped, abnormal exit).
   c. Present to user: list each uncompleted task with subject, status, and possible cause.
   d. `AskUserQuestion`: header "[W.Tasks]", question "There are uncompleted tasks from the previous phase. How to proceed?", options:
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
- `.ca/workflows/<active_id>/rounds/<N>/PLAN.md` (N = fix_round, default 0; round 0 → `rounds/0/PLAN.md`)
- `.ca/workflows/<active_id>/rounds/<N>/TASKS.csv` (same N)
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick` or `workflow_type: instant`)

Read `fix_round` from STATUS.md (default: 0). Use N = fix_round for all round-scoped paths above.

Read `worktree_path` from STATUS.md. If present, this is the **code working directory** — executor agents operate on source files here. The orchestrator continues using `<project-root>` for all `.ca/` file operations (reading PLAN.md, writing SUMMARY.md, etc.).

Also read `project_worktrees` from STATUS.md. If present and the config output contains `## Project`, use the worktree paths from the triples as the project directory paths when passing to executor agents (instead of the original `project_dirs` paths).

Also read the config output. If it contains `## Project`:
- Extract `project_dirs` and `project_rules` from the config output.
- When launching ca-executor agents, include the project directory information in the prompt:
  - "Project directories: <list of label: path pairs>"
  - "Additional rules to follow: <content of each rules file>"
- Read the content of each rules file listed in `project_rules` and include it in the executor prompt as additional context.

### 1b. Ensure codebase map exists

**CRITICAL — Do NOT skip this step.** Check if `.ca/map.md` exists:

1. Run: `ls <project-root>/.ca/map.md 2>/dev/null` to check existence.
2. If the file does NOT exist AND the project is not empty (has source files): scan the project structure yourself using Glob/Read tools and write `.ca/map.md` directly. **Do NOT use `Skill(ca:map)` — Skill calls will terminate the current session.** Write a basic map with directory structure and key files.
3. If the project is empty (no source files): skip (map will be created in step 7).

Mark "Prepare execution" as `completed`.

### 2. Resolve model for ca-executor

Read `ca-executor_model` from the config JSON already loaded. This is the already-resolved model name (opus/sonnet/haiku). Pass to Task tool.

### 3. Parse execution order from TASKS.csv

Read `rounds/<N>/TASKS.csv` via `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js get --file .ca/workflows/<active_id>/rounds/<N>/TASKS.csv --json`. Group rows by `phase`: rows sharing a `phase` run in parallel; phases run in ascending numeric order (sequential). **Resume:** skip rows whose `dev` is already `done`; start from the first `dev` ≠ `done` row.

For each task row, `TaskCreate`: subject "Task <id>: <title>", activeForm "Executing task <id>". Pass the row's `description` (and REQUIREMENT/BRIEF content) to the executor.

### 3a. Sequential execution

Mark the corresponding "Task <id>: <title>" task as `in_progress`.
Launch a single `ca-executor` with the task row's `description` inlined. Wait for completion before next item.
If `worktree_path` exists in STATUS.md, pass `worktree_path` as the "Code working directory" to the executor (separate from `<project-root>` which the orchestrator uses for `.ca/` files). If `project_worktrees` exists, pass the worktree paths from the triples as the project directory paths.
After executor completes successfully: the ORCHESTRATOR (not the executor) flips the row: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update --file .ca/workflows/<active_id>/rounds/<N>/TASKS.csv --id <id> --field dev --value done`. Executors return results only; they never write TASKS.csv.
Mark the task as `completed`.

### 3b. Parallel execution

Read `max_concurrency` from the config JSON already loaded. If items exceed limit, split into batches. Mark all tasks in the current batch as `in_progress`. Launch multiple `ca-executor` agents **in the same message**, each receiving:
- Task row `description` inlined
- REQUIREMENT.md/BRIEF.md content
- Project root path
- Output file: `SUMMARY-executor-{N}.md`
  - If `worktree_path` exists: pass `worktree_path` as "Code working directory" instead of project root for code operations

Wait for all to complete before next sequential item. As each executor completes: mark the corresponding task as `completed`.
After the entire batch completes, the ORCHESTRATOR writes each completed row sequentially (no parallel-write races): `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update --file .ca/workflows/<active_id>/rounds/<N>/TASKS.csv --id <id> --field dev --value done` for each successfully executed task. Executors return results only; they never write TASKS.csv.

### 4. Write SUMMARY.md

Mark "Write SUMMARY.md" as `in_progress`.

- **Single mode**: Write agent's summary to `.ca/workflows/<active_id>/rounds/<N>/SUMMARY.md` (N = fix_round, default 0).
- **Parallel mode**: Merge all `SUMMARY-executor-*.md` into `.ca/workflows/<active_id>/rounds/<N>/SUMMARY.md`, delete individual files.

After writing SUMMARY.md, append a per-round Execute summary line to `.ca/workflows/<active_id>/TRACKING.md` (create lazily) under `## Rounds → ### Round <N>` (Execute: plan-vs-execution divergence if any), per `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/tracking-format.md`. Do not duplicate SUMMARY.md content.

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

### 7b. Auto-commit after execution

Read `use_worktrees` from the config JSON already loaded.
Read STATUS.md for `worktree_path` and `workflow_type`.

Determine whether to auto-commit and which directory to use:
- If `worktree_path` exists in STATUS.md: commit in `<worktree_path>` (worktree mode — all workflow types)
- Else if `workflow_type: instant`: commit in `<project-root>` (instant always commits, even without worktree)
- Else: skip auto-commit (non-worktree mode for quick/standard/write — no execute-time commit)

If committing:
1. Check for changes: `git -C <code_dir> status --porcelain`. If no changes, skip.
2. Stage all changes: `git -C <code_dir> add -A`.
3. Read BRIEF.md first line (after `# Brief`) for title.
4. Commit: `git -C <code_dir> commit -m "wip: <brief title>"`.
5. After a successful commit, flip `git=done` for each executed task in this round: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update --file .ca/workflows/<active_id>/rounds/<N>/TASKS.csv --id <id> --field git --value done`.

For non-worktree standard/quick/write (no commit here): leave `git`=`pending` for all tasks — finish flips it. **Note:** `git` tracks commit state only; `pending` after execute is normal in non-worktree mode and must not mislead resume/status.

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
