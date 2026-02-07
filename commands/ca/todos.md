# /ca:todos — List All Todos

## Prerequisites

Check `.ca/todos.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

Read and display the contents of `.ca/todos.md`.

If the file is empty (only has the header), tell the user there are no todo items yet and suggest using `/ca:todo <item>` to add one.

Display items with their checkbox status:
- `- [ ]` for pending items
- `- [x]` for completed items
- `- [-]` for cancelled items

### Marking items as done or cancelled

If the user wants to mark items as done (`[x]`) or cancelled (`[-]`):

1. Update the checkbox: `- [ ]` → `- [x]` or `- [-]`
2. Update the time tag blockquote: append `| Completed: YYYY-MM-DD` (for done) or `| Cancelled: YYYY-MM-DD` (for cancelled) to the existing `> Added: ...` line. If no time tag exists, add one: `> Completed: YYYY-MM-DD` or `> Cancelled: YYYY-MM-DD`
3. Move the item (with all its blockquote lines) from the `# Todo List` section to the `# Archive` section at the bottom of the file
4. Save the updated file and confirm to the user

### Removing items

If the user wants to remove an item entirely, delete it from the file.
