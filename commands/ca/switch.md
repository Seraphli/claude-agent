# /ca:switch — Switch Active Workflow

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config.

## Prerequisites

Check `.ca/workflows/` directory exists and contains at least one workflow. If not, tell the user to run `/ca:new` first and stop.

## Behavior

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
