---
name: ca-todos
description: Lists all todo items with checkbox status and archive. Use when reviewing the todo list.
---

# /ca:todos — List All Todos

**CRITICAL — Code Modification Policy**: This command reads .ca/todos.md. May modify it when marking items as done/cancelled.

## Prerequisites

Before reading `.ca/todos.md`, if the file exists and contains a line matching `^# Archive`, follow `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/todos-migration.md` to migrate to the split layout, then continue.

Check `.ca/todos.md` exists. If not, create it with:

```markdown
# Todo List
```

Then continue with the normal flow.

## Behavior

**IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.

Read `.ca/todos.md` (active items). If `.ca/todos-archive.md` exists, also read it. Display the result in a single output: first the active items (from `.ca/todos.md`), then a clearly-labeled archive section with the archived items (from `.ca/todos-archive.md`).

If both files are missing or contain no items, tell the user there are no todo items yet and suggest using `/ca:todo <item>` to add one.

Display items with their checkbox status:
- `- [ ]` for pending items
- `- [x]` for completed items
- `- [-]` for cancelled items

### Marking items as done or cancelled

If the user wants to mark items as done (`[x]`) or cancelled (`[-]`):

1. Update the checkbox: `- [ ]` → `- [x]` or `- [-]`
2. Update the time tag blockquote: append `| Completed: YYYY-MM-DD` (for done) or `| Cancelled: YYYY-MM-DD` (for cancelled) to the existing `> Added: ...` line. If no time tag exists, add one: `> Completed: YYYY-MM-DD` or `> Cancelled: YYYY-MM-DD`
3. Remove the item (with all its blockquote lines) from `.ca/todos.md`. Append it to `.ca/todos-archive.md` under the `# Archive` header. If `.ca/todos-archive.md` does not exist, create it with a single `# Archive` header line followed by the item.
4. Save the updated file and confirm to the user

### Removing items

If the user wants to remove an item entirely, delete it from the file.
