# /ca:todo — Add a Todo Item

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/todos.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Get the item

The user's message after `/ca:todo` contains the item to add. If empty, ask what they want to add.

### 2. Append to todos.md

Read `.dev/todos.md`, then append the new item. **Always preserve the user's exact original input**:

```markdown
- [ ] <user's exact original input>
```

If you have additional understanding or notes to add, put them on the next line as a blockquote:

```markdown
- [ ] <user's exact original input>
  > Note: <your understanding or clarification>
```

### 3. Confirm

Tell the user the item has been added. Show the updated todo list.
