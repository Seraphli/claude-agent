# /ca:switch — Switch Active Workflow

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

Check `.ca/workflows/` directory exists and contains at least one workflow. If not, tell the user to run `/ca:new` first and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. List available workflows

Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. Parse the JSON array to get all workflows with their `workflow_id`, `workflow_type`, `current_step`, `brief`, and `active` fields.

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

Before switching, read the departing workflow's STATUS.md and set `status_note` based on its `current_step`, e.g.: "Switched away during <current_step> phase." Write this `status_note` to the departing workflow's STATUS.md (append the line `status_note: Switched away during <current_step> phase.`).

Write the selected workflow ID to `.ca/active.md`.

Tell the user the active workflow has been switched. Show the new active workflow's status and suggest the next command.

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

### 4b. Switch git branch (if enabled)

Read `use_branches` from the config JSON already loaded.
Read the **target** workflow's STATUS.md for `branch_name`.

1. Check uncommitted changes: `git status --porcelain`. If not clean:
   - Check current branch: `git branch --show-current`.
   - If current branch starts with `ca/` (workflow branch): auto-commit: `git add -A && git commit -m "wip: save uncommitted changes"`.
   - Otherwise: `AskUserQuestion`: header "Git", question "There are uncommitted changes on a non-workflow branch. How to proceed?", options:
     - "Commit" — "Commit changes to current branch before switching"
     - "Cancel" — "Cancel switch"
   - If **Commit**: `git add -A && git commit -m "wip: save uncommitted changes"`.
   - If **Cancel**: Revert `.ca/active.md` to previous workflow ID. Stop.
2. If `use_branches` is `true` AND target workflow has `branch_name`:
   - Switch branch: `git checkout <branch_name>`.
   - Tell the user the git branch has been switched.
