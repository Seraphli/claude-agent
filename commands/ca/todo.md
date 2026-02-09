# /ca:todo — Add a Todo Item

## Prerequisites

Check `.ca/todos.md` exists. If not, create it with:

```markdown
# Todo List

# Archive
```

Then continue with the normal flow.

## Behavior

### 1. Get the item

The user's message after `/ca:todo` contains the item to add. If empty, ask what they want to add.

### 2. Append to todos.md

**IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.

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

## Rules

- `/ca:todo` ONLY records todo items. Nothing else.
- Do NOT perform research, answer questions about the todo content, or analyze its implications.
- Do NOT update any memory files (context, errors, or other persistent files).
- After recording the item and confirming, STOP immediately. Do not take any further actions.
