---
name: ca-errors
description: Shows and manages error lessons from project and global levels. Use when user wants to view, clean up, or remove error records.
---

# /ca:errors — Show Error Lessons

**CRITICAL — Code Modification Policy**: This command reads ca-errors.md files. May modify them when removing entries. Do NOT modify source code.

## Prerequisites

No prerequisites.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. Read error files

Read both:
- `.claude/rules/ca:errors.md` (project-level errors)
- `~/.claude/rules/ca:errors.md` (global-level errors)

If neither exists or both are empty, tell the user there are no recorded error lessons.

### 2. Display errors

Show errors organized by level:

```
## Project Error Lessons
<contents or "None">

## Global Error Lessons
<contents or "None">
```

### 3. Management (if requested)

If the user wants to remove entries:
1. Show numbered list of entries
2. Use `AskUserQuestion` to confirm which to remove:
   - header: "Remove"
   - question: "Which entries do you want to remove?"
   - options: list entries (max 4 at a time, paginate if needed)
3. Remove selected entries and save the file
4. Confirm removal to the user
