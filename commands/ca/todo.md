# /ca:todo — Add a Todo Item

Read `.dev/config.md` to determine the user's preferred language. Respond in that language.

## Prerequisites

Check `.dev/todos.md` exists. If not, tell the user to run `/ca:init` first and stop.

## Behavior

### 1. Get the item

The user's message after `/ca:todo` contains the item to add. If empty, ask what they want to add.

### 2. Append to todos.md

Read `.dev/todos.md`, then append the new item as:

```markdown
- [ ] <item>
```

### 3. Confirm

Tell the user the item has been added. Show the updated todo list.
