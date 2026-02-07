# /ca:context — Show Persistent Context

## Prerequisites

No prerequisites.

## Behavior

### 1. Show persistent context

Read and display the contents of `.claude/rules/ca-context.md` (project context) and `~/.claude/rules/ca-context.md` (global context).

If the files are empty or don't exist, tell the user there's no saved context yet and suggest using `/ca:remember <info>` to add some.

### 2. Show loaded files in current context

Check your own context window to determine which files are currently loaded. Do NOT use Glob or Read tools to check the disk — instead, inspect what you can actually "see" in your current conversation context.

For each of the following categories, report whether the file's content is present in your context and show a brief summary if loaded:

**Auto-loaded via rules/ system** (loaded into context automatically by Claude Code if the file exists on disk):
- `~/.claude/rules/ca-rules.md` — shared rules
- `~/.claude/rules/ca-settings.md` — global language settings
- `~/.claude/rules/ca-context.md` — global persistent context
- `~/.claude/rules/ca-errors.md` — global error lessons
- `.claude/rules/ca-settings.md` — project language settings
- `.claude/rules/ca-context.md` — project persistent context
- `.claude/rules/ca-errors.md` — project error lessons

**Runtime config** (loaded only when a workflow command explicitly reads them):
- `~/.claude/ca/config.md` — global config
- `.ca/config.md` — workspace config

**Workflow files** (loaded only when read during workflow command execution):
- `.ca/current/STATUS.md`
- `.ca/current/BRIEF.md`
- `.ca/current/REQUIREMENT.md`
- `.ca/current/RESEARCH.md`
- `.ca/current/PLAN.md`
- `.ca/current/SUMMARY.md`

**Other persistent data:**
- `.ca/todos.md`
- `.ca/map.md`

Only display files that are loaded in your context. Skip files that are not loaded — do not show them at all.
For each loaded file, show: ✅ **Loaded** — followed by a 1-line summary.
