# /ca:quick — Quick Workflow

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings and to check if global config exists.

## Behavior

### 1. Check for global config

If `~/.claude/ca/config.md` does not exist, execute `Skill(ca:settings)` to trigger the settings command in auto-trigger mode for initial setup. After settings completes, continue with the steps below.

### 2. Check for existing workflows

Read `.ca/active.md` (if exists) to get the currently active workflow ID.

If there is an active workflow, read `.ca/workflows/<active_id>/STATUS.md` and check if `verify_completed` is `false`.

If there is an unfinished active workflow:
- **Warn the user**: Tell them there is an unfinished workflow `<active_id>` in `.ca/workflows/`.
- Show what step it was on.
- Use `AskUserQuestion` with:
  - header: "Workflow"
  - question: "There is an unfinished workflow. What would you like to do?"
  - options:
    - "Keep and start new" — "Keep existing workflow, create a new one alongside it"
    - "Archive and start new" — "Archive existing workflow to history, then create new"
    - "Continue current" — "Continue the existing workflow instead"
- If **Keep and start new**: Leave the existing workflow in `workflows/`, continue to create new.
- If **Archive and start new**: Move all files from `.ca/workflows/<active_id>/` to `.ca/history/<next-number>-unfinished/`, remove the workflow directory, then continue.
- If **Continue current**: Stop. Tell the user to finish the current workflow or use `/ca:fix` to go back.

### 3. Create directory structure

Create the following directories and files if they don't exist:

```
.ca/
  todos.md
  workflows/
  history/
```

### 3b. Generate workflow ID

Generate a workflow ID from the user's description:
- Convert to lowercase English slug (letters, numbers, hyphens only)
- Max 30 characters
- If user description is in non-English, use a brief English translation for the slug
- Examples: "Add multi-workflow support" → `add-multi-workflow-support`, "修复登录bug" → `fix-login-bug`
- If `.ca/workflows/<id>/` already exists, append `-2`, `-3`, etc.
- If no description yet (user will provide later), use `workflow-<N>` where N is next available number

Create the workflow directory: `.ca/workflows/<id>/`

### 4. Collect initial requirement description and link to todo

**IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.

**If the user provided a description** with this command:

**First, check if the user's description is a todo reference** (e.g., "处理 todo", "处理所有 todo", "处理 todo 中的 XXX 问题", "handle the todos", or similar expressions indicating they want to work on existing todo items rather than describing a new requirement). If so, treat this as if the user did NOT provide a description — go to the "If the user did NOT provide a description" flow below (list todos and let user select). Do NOT use the reference text (e.g., "处理 todo") as the requirement description.

1. Read `.ca/todos.md` and find all uncompleted todo items (under `# Todo List`, not in `# Archive`).
2. Analyze the user's description and see if it matches any existing todo item.
3. If a match is found, use `AskUserQuestion` with:
   - header: "Link Todo"
   - question: "I found a matching todo: <todo text>. Link this requirement to it?"
   - options:
     - "Yes, link" — "Link to this todo"
     - "No, skip" — "Don't link"
   - If **Yes, link**: Save the todo text for linking in step 5.
   - If **No, skip**: Continue without linking.
4. If no match is found, use `AskUserQuestion` with:
   - header: "Add Todo"
   - question: "This requirement doesn't match any existing todo. Add it as a new todo item?"
   - options:
     - "Yes, add" — "Add to todo list"
     - "No, skip" — "Don't add"
   - If **Yes, add**: Append to `.ca/todos.md` with format `- [ ] <user's description>` and `> Added: YYYY-MM-DD` (use today's date). Save the todo text for linking in step 5.
   - If **No, skip**: Continue without linking.

**If the user did NOT provide a description**:
1. Read `.ca/todos.md` and find all uncompleted todo items.
2. Analyze and present them to the user: **"Here are your current todos. Which one would you like to work on? (Or describe a new requirement)"**
   - Show each uncompleted todo with a number.
3. If the user selects a todo, use that as the requirement description and save it for linking in step 5.
4. If the user provides a new description instead, use it and proceed to match/add logic as above.

### 5. Write BRIEF.md

Write `.ca/workflows/<id>/BRIEF.md` with:

```markdown
# Brief

<user's description>

linked_todo: <todo text if linked, otherwise omit this line>
```

**IMPORTANT**: The `linked_todo` value must be the **exact original text** from `todos.md`. Do NOT modify, abbreviate, rephrase, or summarize the todo text. Copy it verbatim.

Include `linked_todo` if the user chose "Yes, link" or "Yes, add" in step 4. Omit this line only if the user chose "No, skip" or no todo interaction occurred.

### 6. Initialize STATUS.md

Write `.ca/workflows/<id>/STATUS.md` with:

```markdown
# Workflow Status

workflow_id: <id>
workflow_type: quick
current_step: quick
init_completed: true
discuss_completed: true
plan_completed: false
plan_confirmed: false
execute_completed: false
verify_completed: false
```

Write `.ca/active.md` with the workflow ID (plain text, no markdown formatting, just the ID string).

### 7. Confirm completion

**CRITICAL**: This command ONLY creates workflow structure files (BRIEF.md, STATUS.md, active.md) and records the user's requirement description. You MUST NOT:
- Read source code files or project files (other than todos.md and workflow management files)
- Analyze, summarize, or research the codebase
- Generate any content beyond what the user provided
- Execute any part of the requirement task

All research, analysis, and implementation belong to later phases (`/ca:plan`, `/ca:execute`). Simply record the user's description verbatim and create the workflow files.

Tell the user the quick workflow has been created. Show the brief and the workflow ID. Suggest next steps:
- Run `/ca:plan` to create the implementation plan (or use `/ca:next`)
- Suggest using `/clear` before proceeding to free up context

**Do NOT proceed to plan automatically. Wait for the user to invoke the next command.**
