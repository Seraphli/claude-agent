# /ca:context — Show Persistent Context

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.ca/context.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Show persistent context

Read and display the contents of `.ca/context.md`.

If the file is empty (only has the header), tell the user there's no saved context yet and suggest using `/ca:remember <info>` to add some.

### 2. Show loaded files in current context

List all files that the current workflow commands load into context. Check which of the following files exist and display them:

**Always loaded (by all commands):**
- `~/.claude/ca/config.md` — global config
- `.ca/config.md` — workspace config (if exists)
- `commands/ca/_rules.md` — shared rules

**Error history (loaded by all workflow commands):**
- `.ca/errors.md` — project-level error lessons (if exists)
- `~/.claude/ca/errors.md` — global error lessons (if exists)

**Workflow files (loaded when in active workflow):**
- `.ca/current/STATUS.md` (if exists)
- `.ca/current/BRIEF.md` (if exists)
- `.ca/current/REQUIREMENT.md` (if exists)
- `.ca/current/RESEARCH.md` (if exists)
- `.ca/current/PLAN.md` (if exists)
- `.ca/current/SUMMARY.md` (if exists)

**Persistent context:**
- `.ca/context.md`
- `.ca/todos.md`

Display each file with its existence status (present / not found). This helps the user understand what the agent "sees" during the current workflow.
