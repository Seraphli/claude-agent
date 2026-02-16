# /ca:batch — Batch Execute Workflows

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values.

## Prerequisites

Check `.ca/workflows/` exists. Scan for eligible workflows:
- `plan_confirmed: true` and `execute_completed: false` (needs execute + verify)
- `execute_completed: true` and `verify_completed: false` (needs verify only)

Already completed workflows (`verify_completed: true`) are skipped.
If none found, tell the user there are no workflows ready for batch execution and stop.

## Behavior

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
Execute `Skill(ca:verify)` for the current workflow.
- The `batch_mode: true` flag tells verify to: skip manual criteria, skip user acceptance, and auto-update STATUS.md on success.

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

If 2+ passed workflows, compare changed file lists between each pair:
- No overlapping files → **Independent**
- Overlapping files → **Code overlap** (list overlapping files)

Present the analysis.

#### 4c. Recommendations
- **Independent passed**: "Run `/ca:switch <id>` then `/ca:finish` for each."
- **Overlapping passed**: "Review overlapping files before finishing."
- **Failed**: "Run `/ca:switch <id>` then `/ca:fix`."

### 5. Restore active workflow

After all workflows are processed:
- If there are remaining unfinished workflows in `.ca/workflows/`, set `active.md` to one of them.
- If no workflows remain, delete `.ca/active.md`.
