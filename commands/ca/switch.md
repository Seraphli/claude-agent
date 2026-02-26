# /ca:switch — Switch Active Workflow

Read config (use Read tool, not search/glob): `.ca/config.md` (workspace) → `~/.claude/ca/config.md` (global) → `~/.claude/ca/references/config-defaults.md` (defaults).

## Prerequisites

Check `.ca/workflows/` directory exists and contains at least one workflow. If not, tell the user to run `/ca:new` first and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. List available workflows

Scan `.ca/workflows/` for subdirectories. For each, read its `STATUS.md` to get:
- `workflow_id`
- `workflow_type` (standard/quick)
- `current_step`
- Key status flags

Also read its `BRIEF.md` first line (after `# Brief`) for a short description.

Read `.ca/active.md` to identify the currently active workflow.

### 2. Present workflow list

Display a table:

| # | ID | Type | Current Step | Brief |
|---|-----|------|-------------|-------|
| 1 | feature-x | standard | plan | Add feature X... |
| 2 | fix-bug | quick | execute | Fix login bug... |

Mark the currently active workflow with `→` or `(active)`.

### 3. Ask user to select

Use `AskUserQuestion` with:
- header: "Switch"
- question: "Which workflow do you want to switch to?"
- options: List each non-active workflow as an option (label: ID, description: brief summary)

### 4. Update active.md

Write the selected workflow ID to `.ca/active.md`.

Tell the user the active workflow has been switched. Show the new active workflow's status and suggest the next command.

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

### 4b. Switch git branch (if enabled)

Read `use_branches` from config: `.ca/config.md` → `~/.claude/ca/config.md` → `~/.claude/ca/references/config-defaults.md`.
Read the **target** workflow's STATUS.md for `branch_name`.

If `use_branches` is `true` AND target workflow has `branch_name`:
1. Check uncommitted changes: `git status --porcelain`. If not clean:
   - `AskUserQuestion`: header "Git", question "Uncommitted changes detected. Stash before switching branch?", options:
     - "Stash" — "Stash and switch"
     - "Cancel" — "Cancel switch"
   - If **Stash**: `git stash`.
   - If **Cancel**: Revert `.ca/active.md` to previous workflow ID. Stop.
2. Switch branch: `git checkout <branch_name>`.
3. Tell the user the git branch has been switched.
