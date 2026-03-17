---
name: ca-forget
description: Removes information from persistent context. Use when user wants to remove stored context.
---

# /ca:forget — Remove from Persistent Context

**CRITICAL — Code Modification Policy**: This command only modifies ca-context.md files. Do NOT modify source code.

## Prerequisites

No prerequisites — context files are checked on demand.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. Ask target level

Use `AskUserQuestion` with:
- header: "Level"
- question: "Remove from global or project context?"
- options:
  - "Project" — "Remove from .claude/rules/ca:context.md"
  - "Global" — "Remove from ~/.claude/rules/ca:context.md"

### 2. Read current context

Based on the user's choice:
- **Project**: Read `.claude/rules/ca:context.md` and display its contents.
- **Global**: Read `~/.claude/rules/ca:context.md` and display. If missing, tell user and stop.

### 3. Identify what to remove

The user's message after `/ca:forget` describes what to remove. Match it against existing entries.

If the match is ambiguous, show the matching entries and ask the user to confirm which one(s) to remove.

### 4. Remove and confirm

Remove the matching entry/entries from the chosen context file and write the updated file.

Tell the user what was removed and show the remaining context.
