# /ca:list — List All Workflows

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config.

## Behavior

### 1. Scan workflows

Check if `.ca/workflows/` exists. If not, tell the user there are no active workflows.

Scan `.ca/workflows/` for subdirectories. For each, read:
- `STATUS.md` — workflow_type, current_step, all status flags
- `BRIEF.md` — first line after `# Brief` for description

Read `.ca/active.md` to identify the currently active workflow.

### 2. Display summary table

Present a table with all workflows:

| | ID | Type | Step | Status Flags | Brief |
|---|-----|------|------|-------------|-------|
| → | feature-x | standard | plan | ✅init ✅discuss ⬜plan | Add feature X... |
| | fix-bug | quick | execute | ✅init ✅discuss ✅plan ✅execute ⬜verify | Fix login bug... |

Use `→` to mark the active workflow.

Show status flags as checkmarks (✅ completed, ⬜ pending).

### 3. Show summary counts

Display:
- Total workflows: N
- Plan confirmed (ready for batch): N
- In progress: N

Suggest relevant next commands (e.g., `/ca:batch` if any are plan_confirmed, `/ca:switch` to change active).
