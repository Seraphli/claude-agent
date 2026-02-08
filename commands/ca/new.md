# /ca:new — Start a New Requirement

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings and to check if global config exists.

## Behavior

### 1. Check for global config

If `~/.claude/ca/config.md` does not exist, execute `Skill(ca:settings)` to trigger the settings command in auto-trigger mode for initial setup. After settings completes, continue with the steps below.

### 2. Check for unfinished workflow

If `.ca/current/STATUS.md` exists, check if `verify_completed` is `false`.

If there is an unfinished workflow:
- **Warn the user**: Tell them there is an unfinished workflow in `.ca/current/`.
- Show what step it was on.
- Use `AskUserQuestion` with:
  - header: "Archive"
  - question: "Do you want to archive the unfinished workflow and start fresh?"
  - options:
    - "Archive and start fresh" — "Move old files to history and start new"
    - "Keep current" — "Continue the existing workflow"
- If **Archive and start fresh**: Move all files from `.ca/current/` to `.ca/history/<next-number>-unfinished/`, then continue.
- If **Keep current**: Stop. Tell the user to finish the current workflow first or use `/ca:fix` to go back.

### 3. Create directory structure

Create the following directories and files if they don't exist:

```
.ca/
  todos.md
  current/
  history/
```

### 4. Collect initial requirement description and link to todo

**IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.

**If the user provided a description** with this command:
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

Write `.ca/current/BRIEF.md` with:

```markdown
# Brief

<user's description>

linked_todo: <todo text if linked, otherwise omit this line>
```

**IMPORTANT**: The `linked_todo` value must be the **exact original text** from `todos.md`. Do NOT modify, abbreviate, rephrase, or summarize the todo text. Copy it verbatim.

Include `linked_todo` only if a todo was linked in step 4.

### 6. Initialize STATUS.md

Write `.ca/current/STATUS.md` with:

```markdown
# Workflow Status

workflow_type: standard
current_step: new
init_completed: true
discuss_completed: false
research_completed: false
plan_completed: false
plan_confirmed: false
execute_completed: false
verify_completed: false
```

### 7. Confirm completion

**CRITICAL**: This command ONLY creates the workflow structure and collects the requirement brief. Do NOT read source code files, analyze the codebase, or perform any research. Research belongs in `/ca:research` or `/ca:plan`. Simply record the user's description as-is and create the workflow files.

Tell the user the new requirement has been created. Show the brief. Suggest proceeding with `/ca:discuss` (or `/ca:next`) to discuss and refine the requirements.

**Do NOT proceed to discuss automatically. Wait for the user to invoke the next command.**
