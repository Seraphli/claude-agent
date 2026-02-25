# /ca:batch — Batch Execute Workflows

Read `~/.claude/ca/config.md` (global) then `.ca/config.md` (workspace override).

## Prerequisites

Check `.ca/workflows/` exists. Scan for eligible workflows:
- `plan_confirmed: true` and `execute_completed: false` (needs execute + verify)
- `execute_completed: true` and `verify_completed: false` (needs verify only)

Already completed workflows (`verify_completed: true`) are skipped.
If none found, tell the user there are no workflows ready for batch execution and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. List batch candidates

Present all eligible workflows:

| # | ID | Type | Stage | Brief |
|---|-----|------|-------|-------|
| 1 | feature-x | standard | execute+verify | Add feature X... |
| 2 | fix-bug | quick | verify only | Fix login bug... |

### 2. Confirm batch execution

Use `AskUserQuestion` with:
- header: "Batch"
- question: "Execute these N workflows in order?"
- options:
  - "Execute all" — "Run all listed workflows sequentially"
  - "Cancel" — "Don't execute"

If **Cancel**: Stop.

### 3. Serial execution with checkpoints

Save the current active workflow ID (from `.ca/active.md`) to restore later.
Initialize a results list to track each workflow's outcome.

For each workflow in order:

#### 3a. Set active and create checkpoint
1. Write the workflow ID to `.ca/active.md` (set as active).
2. Write `batch_mode: true` to the workflow's STATUS.md.
3. Create a git checkpoint: `git tag ca-batch-checkpoint-<workflow_id>` on the current HEAD.

#### 3b. Execute (if needed)
If `execute_completed: false`: Execute `Skill(ca:execute)` for the current workflow.
If `execute_completed: true`: skip execution.

#### 3c. Verify
Execute `Skill(ca:verify)`. `batch_mode: true` → skip manual criteria, skip user acceptance, auto-update STATUS.md.

#### 3d. Handle results

**If verify succeeds** (verify_completed: true):
1. Stage changed files and commit: generate a commit message based on PLAN.md and SUMMARY.md, using format `<type>: <title>` with body details.
2. Record the commit hash and changed file list for this workflow.
3. Remove `batch_mode` from STATUS.md.
4. Remove checkpoint tag: `git tag -d ca-batch-checkpoint-<workflow_id>`.
5. Record success in results list.

**If verify fails**:
1. Roll back: `git reset --hard ca-batch-checkpoint-<workflow_id>`.
2. Clean up tag: `git tag -d ca-batch-checkpoint-<workflow_id>`.
3. Reset STATUS.md: `plan_confirmed: true`, `execute_completed: false`, `verify_completed: false`.
4. Remove `batch_mode` from STATUS.md.
5. Record failure reason in results list.
6. Continue to next workflow.

### 4. Post-batch analysis

#### 4a. Present summary table

| # | ID | Status | Notes |
|---|-----|--------|-------|
| 1 | feature-x | ✅ Pass | Committed: abc1234 |
| 2 | fix-bug | ❌ Fail | <failure reason> |

Show counts: Passed / Failed / Total.

#### 4b. Code independence analysis (for passed workflows)

If 2+ passed: compare changed files between pairs. No overlap → Independent. Overlap → list files.

#### 4c. Recommendations
- **Independent**: `/ca:switch <id>` → `/ca:finish` each.
- **Overlapping**: Review overlapping files first.
- **Failed**: `/ca:switch <id>` → `/ca:fix`.

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

### 5. Restore active workflow

After all workflows are processed:
- If there are remaining unfinished workflows in `.ca/workflows/`, set `active.md` to one of them.
- If no workflows remain, delete `.ca/active.md`.
