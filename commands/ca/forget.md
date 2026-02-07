# /ca:forget — Remove from Persistent Context

## Prerequisites

No prerequisites — context files are checked on demand.

## Behavior

### 1. Ask target level

Use `AskUserQuestion` with:
- header: "Level"
- question: "Remove from global or project context?"
- options:
  - "Project" — "Remove from .claude/rules/ca-context.md"
  - "Global" — "Remove from ~/.claude/rules/ca-context.md"

### 2. Read current context

Based on the user's choice:
- **Project**: Read `.claude/rules/ca-context.md` and display its contents.
- **Global**: Read `~/.claude/rules/ca-context.md` and display its contents. If the file doesn't exist, tell the user there is no global context and stop.

### 3. Identify what to remove

The user's message after `/ca:forget` describes what to remove. Match it against existing entries.

If the match is ambiguous, show the matching entries and ask the user to confirm which one(s) to remove.

### 4. Remove and confirm

Remove the matching entry/entries from the chosen context file and write the updated file.

Tell the user what was removed and show the remaining context.
