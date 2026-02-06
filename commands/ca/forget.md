# /ca:forget — Remove from Persistent Context

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/context.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Read current context

Read `.dev/context.md` and display its contents.

### 2. Identify what to remove

The user's message after `/ca:forget` describes what to remove. Match it against existing entries.

If the match is ambiguous, show the matching entries and ask the user to confirm which one(s) to remove.

### 3. Remove and confirm

Remove the matching entry/entries from `.dev/context.md` and write the updated file.

Tell the user what was removed and show the remaining context.
