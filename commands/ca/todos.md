# /ca:todos — List All Todos

Read `.dev/config.md` to determine the user's preferred language. Respond in that language.

## Prerequisites

Check `.dev/todos.md` exists. If not, tell the user to run `/ca:init` first and stop.

## Behavior

Read and display the contents of `.dev/todos.md`.

If the file is empty (only has the header), tell the user there are no todo items yet and suggest using `/ca:todo <item>` to add one.

Display items with their checkbox status:
- `- [ ]` for pending items
- `- [x]` for completed items

If the user wants to mark items as done or remove them, do so and update the file.
