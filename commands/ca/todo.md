# /ca:todo — Add a Todo Item

## Prerequisites

Check `.ca/todos.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Get the item

The user's message after `/ca:todo` contains the item to add. If empty, ask what they want to add.

### 2. Append to todos.md

Read `.ca/todos.md`, then append the new item. **Always preserve the user's exact original input**:

```markdown
- [ ] <user's exact original input>
  > Added: YYYY-MM-DD
```

Replace `YYYY-MM-DD` with today's date.

If you have additional understanding or notes to add, put them on the same blockquote line or add another:

```markdown
- [ ] <user's exact original input>
  > Added: YYYY-MM-DD | Note: <your understanding or clarification>
```

### 3. Confirm

Tell the user the item has been added. Show the updated todo list.
