# /ca:context — Show Persistent Context

## Prerequisites

No prerequisites.

## Behavior

### 1. Show persistent context

Read and display the contents of `.claude/rules/ca-context.md` (project context) and `~/.claude/rules/ca-context.md` (global context).

If the files are empty or don't exist, tell the user there's no saved context yet and suggest using `/ca:remember <info>` to add some.

### 2. Show loaded files in current context

List all files that the current workflow commands load into context. Check which of the following files exist and display them:

**Auto-loaded via rules/ system:**
- `~/.claude/rules/ca-rules.md` — shared rules (if exists)
- `~/.claude/rules/ca-settings.md` — global language settings (if exists)
- `~/.claude/rules/ca-context.md` — global persistent context (if exists)
- `~/.claude/rules/ca-errors.md` — global error lessons (if exists)
- `.claude/rules/ca-settings.md` — project language settings (if exists)
- `.claude/rules/ca-context.md` — project persistent context (if exists)
- `.claude/rules/ca-errors.md` — project error lessons (if exists)

**Runtime config (read by workflow commands):**
- `~/.claude/ca/config.md` — global config (if exists)
- `.ca/config.md` — workspace config (if exists)

**Workflow files (loaded when in active workflow):**
- `.ca/current/STATUS.md` (if exists)
- `.ca/current/BRIEF.md` (if exists)
- `.ca/current/REQUIREMENT.md` (if exists)
- `.ca/current/RESEARCH.md` (if exists)
- `.ca/current/PLAN.md` (if exists)
- `.ca/current/SUMMARY.md` (if exists)

**Other persistent data:**
- `.ca/todos.md` (if exists)

Display each file with its existence status (present / not found). This helps the user understand what the agent "sees" during the current workflow.
