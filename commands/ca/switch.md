# /ca:switch — Switch Active Workflow

Read `~/.claude/ca/config.md` (global) then `.ca/config.md` (workspace override).

## Prerequisites

Check `.ca/workflows/` directory exists and contains at least one workflow. If not, tell the user to run `/ca:new` first and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (selects "Other"/chat or provides text input), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. Do NOT ignore unselected options and continue with default behavior.

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
