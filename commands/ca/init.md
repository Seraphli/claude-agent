# /ca:init — Initialize Workspace

You are setting up the CA development workflow for this project.

## Steps

### 1. Create directory structure

Create the following directories and files if they don't exist:

```
.dev/
  config.md
  context.md
  todos.md
  current/
    STATUS.md
  history/
```

### 2. Ask language preference

Ask the user which language they prefer for interactions. Use `AskUserQuestion` with options:
- English
- 中文 (Chinese)

### 3. Write config

Write `.dev/config.md` with:

```markdown
# CA Configuration

language: <chosen language>
```

### 4. Initialize STATUS.md

Write `.dev/current/STATUS.md` with:

```markdown
# Workflow Status

current_step: init
init_completed: true
discuss_completed: false
research_completed: false
plan_completed: false
plan_confirmed: false
execute_completed: false
verify_completed: false
```

### 5. Initialize empty files

- `.dev/context.md` — write `# Persistent Context` followed by a blank line
- `.dev/todos.md` — write `# Todo List` followed by a blank line

### 6. Confirm completion

Tell the user the workspace is initialized and suggest starting with `/ca:discuss` when they have a task.
