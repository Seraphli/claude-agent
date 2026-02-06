# /ca:todos — List All Todos

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/todos.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

Read and display the contents of `.dev/todos.md`.

If the file is empty (only has the header), tell the user there are no todo items yet and suggest using `/ca:todo <item>` to add one.

Display items with their checkbox status:
- `- [ ]` for pending items
- `- [x]` for completed items

If the user wants to mark items as done or remove them, do so and update the file.
