# /ca:list — List All Workflows

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Behavior

### 1. Scan workflows

Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. Parse the JSON array.
If the array is empty, tell the user there are no active workflows.

The list includes `workflow_id`, `workflow_type`, `current_step`, `brief`, and `active` fields for each workflow. For full status flags (e.g., `plan_confirmed`, `execute_completed`), read the individual `STATUS.md` files directly.

### 2. Display summary table

Present a table with all workflows:

| | ID | Type | Step | Branch | Status Flags | Brief |
|---|-----|------|------|--------|-------------|-------|
| → | feature-x | standard | plan | ca/feature-x | ✅init ✅discuss ⬜plan | Add feature X... |
| | fix-bug | quick | execute | | ✅init ✅discuss ✅plan ✅execute ⬜verify | Fix login bug... |

Use `→` to mark the active workflow.

The Branch column is only shown when at least one workflow has a `branch_name` in its STATUS.md. If no workflows have a branch, omit the Branch column entirely.

Show status flags as checkmarks (✅ completed, ⬜ pending).

### 3. Show summary counts

Display:
- Total workflows: N
- Plan confirmed (ready for batch): N
- In progress: N

Suggest relevant next commands (e.g., `/ca:batch` if any are plan_confirmed, `/ca:switch` to change active).

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.
