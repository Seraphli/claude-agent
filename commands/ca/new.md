# /ca:new — Start a New Requirement

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

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

### 4. Collect initial requirement description

If the user provided a description with this command (as arguments), use it.

Otherwise, ask: **"What do you want to implement? (A brief description is enough)"**

### 5. Write BRIEF.md

Write `.dev/current/BRIEF.md` with:

```markdown
# Brief

<user's description>
```

### 6. Initialize STATUS.md

Write `.dev/current/STATUS.md` with:

```markdown
# Workflow Status

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

Tell the user the new requirement has been created. Show the brief. Suggest proceeding with `/ca:discuss` to discuss and refine the requirements.

**Do NOT proceed to discuss automatically. Wait for the user to invoke the next command.**
