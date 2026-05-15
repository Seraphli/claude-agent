---
name: ca-batch
description: Batch executes multiple confirmed workflows sequentially. Use when multiple plans are confirmed and ready.
---
# /ca:batch — Batch Execute Workflows

**CRITICAL — Code Modification Policy**: This command orchestrates ca-execute and ca-verify skills. Does not modify code directly.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Prerequisites

Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. Find eligible workflows from the output:
- `plan_confirmed: true` and `execute_completed: false` (needs execute + verify)
- `execute_completed: true` and `verify_completed: false` (needs verify only)

Note: the list command returns summary fields only. Read each eligible workflow's STATUS.md directly for full field values when needed.
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

#### 3a. Set active and prepare
1. Write the workflow ID to `.ca/active.md` (set as active).
2. Write `batch_mode: true` to the workflow's STATUS.md. Also set `status_note` for the workflow being processed.
3. Read `use_worktrees` from the config JSON already loaded.
   Read STATUS.md for `branch_name`.
4. **If worktree mode** (`worktree_path` exists): no checkout needed. Read `worktree_path` from STATUS.md — executor/verifier will use this as code working directory.
5. **If non-worktree mode**: Create git checkpoint: `git tag ca-batch-checkpoint-<workflow_id>`.

#### 3b. Execute (if needed)
If `execute_completed: false`: Execute `Skill(ca:execute)` for the current workflow.
If `execute_completed: true`: skip execution.

#### 3c. Verify
Execute `Skill(ca:verify)`. `batch_mode: true` → skip manual criteria, skip user acceptance, auto-update STATUS.md.

#### 3d. Handle results

**If verify succeeds** (verify_completed: true):
1. **If worktree mode**: Execute auto-commit already handled by execute step 7b. No additional commit needed. Remove `batch_mode` from STATUS.md. Record success.
2. **If non-worktree mode**: Stage changed files and commit (generate message from PLAN.md/SUMMARY.md). Remove `batch_mode`. Remove checkpoint tag: `git tag -d ca-batch-checkpoint-<workflow_id>`. Record success.

**If verify fails**:
1. **If worktree mode**: no checkout needed — main repo is already on base branch. Reset STATUS.md flags. Remove `batch_mode`. Record failure. Worktree and branch retain their state for later fix.
2. **If non-worktree mode**: `git reset --hard ca-batch-checkpoint-<workflow_id>`. Clean up tag. Reset STATUS.md. Remove `batch_mode`. Record failure.
3. Continue to next workflow.

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
- **Failed**: `/ca:switch <id>` → `/ca:plan`.
- **Branch mode passed**: `/ca:switch <id>` → `/ca:finish` to merge each workflow branch.

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

### 5. Restore active workflow

After all workflows are processed:
- If there are remaining unfinished workflows in `.ca/workflows/`, set `active.md` to one of them.
- If no workflows remain, delete `.ca/active.md`.
- **If worktree mode**: no branch switch needed — main repo is already on its base branch.
