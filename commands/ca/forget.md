# /ca:forget — Remove from Persistent Context

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

Read and follow the rules defined in `commands/ca/_rules.md` (installed at `~/.claude/commands/ca/_rules.md`).

## Prerequisites

Check `.dev/context.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Ask target level

Use `AskUserQuestion` with:
- header: "Level"
- question: "Remove from global or project context?"
- options:
  - "Project" — "Remove from .dev/context.md"
  - "Global" — "Remove from ~/.claude/ca/context.md"

### 2. Read current context

Based on the user's choice:
- **Project**: Read `.dev/context.md` and display its contents.
- **Global**: Read `~/.claude/ca/context.md` and display its contents. If the file doesn't exist, tell the user there is no global context and stop.

### 3. Identify what to remove

The user's message after `/ca:forget` describes what to remove. Match it against existing entries.

If the match is ambiguous, show the matching entries and ask the user to confirm which one(s) to remove.

### 4. Remove and confirm

Remove the matching entry/entries from the chosen context file and write the updated file.

Tell the user what was removed and show the remaining context.
