# /ca:batch — Batch Execute Workflows

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values.

## Prerequisites

Check `.ca/workflows/` exists. Scan for workflows with `plan_confirmed: true` and `execute_completed: false` in their STATUS.md. If none found, tell the user there are no workflows ready for batch execution and stop.

## Behavior

### 1. List batch candidates

Present all plan_confirmed workflows:

| # | ID | Type | Brief |
|---|-----|------|-------|
| 1 | feature-x | standard | Add feature X... |
| 2 | fix-bug | quick | Fix login bug... |

### 2. Confirm batch execution

Use `AskUserQuestion` with:
- header: "Batch"
- question: "Execute these N workflows in order? Each will go through execute → verify."
- options:
  - "Execute all" — "Run all listed workflows sequentially"
  - "Cancel" — "Don't execute"

If **Cancel**: Stop.

### 3. Serial execution with checkpoints

Save the current active workflow ID (from `.ca/active.md`) to restore later.

For each workflow in order:

#### 3a. Set active and create checkpoint

1. Write the workflow ID to `.ca/active.md` (set as active).
2. Create a git checkpoint: `git stash push -m "ca-batch-checkpoint-<workflow_id>"` (if there are uncommitted changes) or use `git tag ca-batch-checkpoint-<workflow_id>` on the current HEAD.
   - Prefer using `git tag` for checkpoints since it's non-destructive.

#### 3b. Execute

Execute `Skill(ca:execute)` for the current workflow.

#### 3c. Verify

After execution completes, execute `Skill(ca:verify)` for the current workflow.
- In batch mode, skip the git commit step in verify (commits will be handled per-workflow during verify but the user has already confirmed batch execution).
- If verify succeeds: The workflow is archived to history automatically by verify.
- If verify fails:
  1. Roll back: `git reset --hard ca-batch-checkpoint-<workflow_id>` to restore to pre-execution state.
  2. Clean up the tag: `git tag -d ca-batch-checkpoint-<workflow_id>`.
  3. Reset the workflow's STATUS.md back to `plan_confirmed: true`, `execute_completed: false`, `verify_completed: false`.
  4. Record the failure reason.
  5. Continue to the next workflow.

#### 3d. Clean up checkpoint

If execution and verify succeeded, remove the checkpoint tag: `git tag -d ca-batch-checkpoint-<workflow_id>`.

### 4. Restore active workflow

After all workflows are processed:
- If there are remaining workflows in `.ca/workflows/`, set `active.md` to one of them.
- If no workflows remain, delete `.ca/active.md`.

### 5. Present batch report

Display a summary report:

| # | ID | Status | Notes |
|---|-----|--------|-------|
| 1 | feature-x | ✅ Success | Archived to history/0005-feature-x |
| 2 | fix-bug | ❌ Failed | Verification failed: <reason>. Rolled back. |

Show counts:
- Succeeded: N
- Failed: N
- Total: N

If any workflows failed, suggest the user review them with `/ca:list` and `/ca:switch` to address failures individually.
