# /ca:remember — Save to Persistent Context

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

Read and follow the rules defined in `commands/ca/_rules.md` (installed at `~/.claude/commands/ca/_rules.md`).

## Prerequisites

Check `.ca/context.md` exists. If not AND the user chose project level, tell the user to run `/ca:new` first and stop.

## Behavior

The user wants to save information to persistent context that will be available across workflow cycles.

### 1. Get the information

The user's message after `/ca:remember` contains the information to save. If empty, ask what they want to remember.

### 2. Ask target level

Use `AskUserQuestion` with:
- header: "Level"
- question: "Save to global or project context?"
- options:
  - "Project" — "Save to .ca/context.md (this project only)"
  - "Global" — "Save to ~/.claude/ca/context.md (all projects)"

### 3. Append to context file

Based on the user's choice:
- **Project**: Read `.ca/context.md`, then append the new information as a bullet point with a timestamp:
  ```
  - [YYYY-MM-DD] <information>
  ```
- **Global**: Read `~/.claude/ca/context.md` (create if it doesn't exist), then append in the same format.

### 4. Confirm

Tell the user the information has been saved and to which level. Show the updated context.
