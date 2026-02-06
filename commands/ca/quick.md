# /ca:quick — Quick Workflow

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

Read and follow the rules defined in `commands/ca/_rules.md` (installed at `~/.claude/commands/ca/_rules.md`).

## Behavior

### 1. Check for global config

If `~/.claude/ca/config.md` does not exist, **automatically run the settings flow inline**:
- Ask the user for the three language settings (interaction_language, comment_language, code_language) using `AskUserQuestion`, one at a time.
- Save to `~/.claude/ca/config.md` as global config.
- Then continue with the steps below.

### 2. Check for unfinished workflow

If `.dev/current/STATUS.md` exists, check if `verify_completed` is `false`.

If there is an unfinished workflow:
- **Warn the user**: Tell them there is an unfinished workflow in `.dev/current/`.
- Show what step it was on.
- Ask: **"Do you want to archive the unfinished workflow and start fresh? (yes/no)"**
- If **yes**: Move all files from `.dev/current/` to `.dev/history/<next-number>-unfinished/`, then continue.
- If **no**: Stop. Tell the user to finish the current workflow first or use `/ca:fix` to go back.

### 3. Create directory structure

Create the following directories and files if they don't exist:

```
.dev/
  context.md
  todos.md
  current/
  history/
```

### 4. Collect initial requirement description and link to todo

**If the user provided a description** with this command:
1. Read `.dev/todos.md` and find all uncompleted todo items (under `# Todo List`, not in `# Archive`).
2. Analyze the user's description and see if it matches any existing todo item.
3. If a match is found, recommend it to the user: **"I found a matching todo: <todo text>. Do you want to link this requirement to it? (yes/no)"**
   - If **yes**: Save the todo text for linking in step 5.
   - If **no**: Continue without linking.
4. If no match is found, ask: **"This requirement doesn't match any existing todo. Should I add it as a new todo item? (yes/no)"**
   - If **yes**: Append to `.dev/todos.md` with format `- [ ] <user's description>` and `> Added: YYYY-MM-DD` (use today's date). Save the todo text for linking in step 5.
   - If **no**: Continue without linking.

**If the user did NOT provide a description**:
1. Read `.dev/todos.md` and find all uncompleted todo items.
2. Analyze and present them to the user: **"Here are your current todos. Which one would you like to work on? (Or describe a new requirement)"**
   - Show each uncompleted todo with a number.
3. If the user selects a todo, use that as the requirement description and save it for linking in step 5.
4. If the user provides a new description instead, use it and proceed to match/add logic as above.

### 5. Write BRIEF.md

Write `.dev/current/BRIEF.md` with:

```markdown
# Brief

<user's description>

linked_todo: <todo text if linked, otherwise omit this line>
```

Include `linked_todo` only if a todo was linked in step 4.

### 6. Initialize STATUS.md

Write `.dev/current/STATUS.md` with:

```markdown
# Workflow Status

workflow_type: quick
current_step: quick
init_completed: true
discuss_completed: true
research_completed: true
plan_completed: false
plan_confirmed: false
execute_completed: false
verify_completed: false
```

### 7. Confirm completion

Tell the user the quick workflow has been created. Show the brief. Suggest proceeding with `/ca:plan` to create the implementation plan.

**Do NOT proceed to plan automatically. Wait for the user to invoke the next command.**
