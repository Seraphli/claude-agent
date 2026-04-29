---
name: ca-restore
description: Restores an archived workflow from history for continued work. Use when user wants to revisit a completed workflow.
---

# /ca:restore — Restore Archived Workflow

**CRITICAL — Code Modification Policy**: This command ONLY moves workflow files and updates status. Do NOT read, analyze, or modify source code.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Prerequisites

Check `.ca/history/` directory exists. If not, tell the user there are no archived workflows and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 0. Initialize task tracking

Create initial tasks for this phase:

1. `TaskCreate`: subject "Scan archived workflows", activeForm "Scanning archives"
2. `TaskCreate`: subject "Restore workflow files", activeForm "Restoring workflow"
3. `TaskCreate`: subject "Create git branch", activeForm "Creating git branch"

Mark "Scan archived workflows" as `in_progress`.

### 1. Scan and display archived workflows

Scan `.ca/history/` for subdirectories. For each directory:
1. Read its `STATUS.md` to get `workflow_id`, `workflow_type`, `current_step`, `verify_completed`.
2. Read its `BRIEF.md` to get the first content line (requirement summary).
3. Determine archive type: if directory name ends with `-unfinished`, mark as "未完成"; if `verify_completed: true` in STATUS.md, mark as "已完成".

Present a numbered list to the user, most recent first (highest number first):

| # | 归档编号 | 工作流 ID | 类型 | 状态 | 需求摘要 |
|---|---------|-----------|------|------|---------|
| 1 | 0059 | fix-squash-merge-branch-delete | quick | 已完成 | finish.md squash merge 后删分支 bug... |
| 2 | 0058 | split-todos-active-archive | quick | 已完成 | 拆分 todos 文件... |
| ... | ... | ... | ... | ... | ... |

If there are more than 20 archived workflows, show the most recent 20 and tell the user there are N more. Offer a "Show all" option.

Use `AskUserQuestion`:
- header: "Restore"
- question: "Select the archived workflow to restore:"
- options: Top 4 most recent archives as options (label: "#N <workflow_id>", description: brief summary truncated to 50 chars)

If user selects one, proceed. If user types a number not in the options, find it in the full list.

Mark "Scan archived workflows" as `completed`. Mark "Restore workflow files" as `in_progress`.

### 2. Check for conflicts and restore

1. Extract `workflow_id` from the selected archive's STATUS.md.
2. Check if `.ca/workflows/<workflow_id>/` already exists:
   - If exists: append `-restored` to the ID (e.g., `fix-login-bug-restored`). If that also exists, append `-restored-2`, etc.
   - Inform the user of the ID change.
3. Move the entire archive directory to `.ca/workflows/<workflow_id>/` using `mv`.
4. Update STATUS.md in the restored workflow:
   - Determine `fix_round`: scan for existing `rounds/` subdirectories. If `rounds/` exists, find the highest N. Set `fix_round` to N+1. If no `rounds/` directory, set `fix_round` to 1.
   - Set `plan_completed: false`
   - Set `plan_confirmed: false`
   - Set `execute_completed: false`
   - Set `verify_completed: false`
   - Set `current_step: plan`
   - Remove `branch_name` line (set to empty or remove)
   - Remove `base_branch` line (set to empty or remove)
   - Set `status_note: Restored from archive <archive_dir_name>. Fix round <N> — ready for planning.`
5. Write the workflow ID to `.ca/active.md`.

Mark "Restore workflow files" as `completed`. Mark "Create git branch" as `in_progress`.

### 3. Create git branch (if enabled)

Read `use_branches` from the config JSON already loaded.

1. Check uncommitted changes: `git status --porcelain`. If not clean:
   - If current branch starts with `ca/`: auto-commit `git add -A && git commit -m "wip: save uncommitted changes"`.
   - Otherwise: `AskUserQuestion`: header "Git", question "There are uncommitted changes. How to proceed?", options:
     - "Commit" — "Commit changes to current branch before proceeding"
     - "Skip branch" — "Don't create a branch for this workflow"
   - If **Commit**: `git add -A && git commit -m "wip: save uncommitted changes"`.
   - If **Skip branch**: Skip branch creation. Continue to step 4.

If `use_branches` is `true`:
1. Check if in a git repository: `git rev-parse --is-inside-work-tree`. If not, skip.
2. Switch to main branch: `git checkout main`.
3. Create and switch to new branch: `git checkout -b ca/<workflow-id>`.
4. Update STATUS.md:
   - Set `branch_name: ca/<workflow-id>`
   - Set `base_branch: main`

Mark "Create git branch" as `completed`.

### 4. Confirm completion

Tell the user the workflow has been restored. Show:
- Workflow ID (and whether it was renamed due to conflict)
- Fix round number
- Original archive source
- Branch name (if created)

Suggest next steps:
- `/ca:plan` (or `/ca:next`) to start planning the fix
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
