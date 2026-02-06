# /ca:fix — Roll Back to a Previous Step

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

Read and follow the rules defined in `commands/ca/_rules.md` (installed at `~/.claude/commands/ca/_rules.md`).

## Prerequisites

Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Show current state

Read `.dev/current/STATUS.md` and display where the workflow currently is.

### 2. Determine target step

The user's message after `/ca:fix` may specify a step name. Valid steps:
- `discuss` — go back to requirements discussion
- `research` — go back to research
- `plan` — go back to planning

If no step is specified, show the options and ask the user where they want to go back to.

### 3. Update STATUS.md

Based on the target step, reset the status flags:

- **Back to discuss**: Set `discuss_completed: false`, `research_completed: false`, `plan_completed: false`, `plan_confirmed: false`, `execute_completed: false`, `verify_completed: false`, `current_step: init`
- **Back to research**: Set `research_completed: false`, `plan_completed: false`, `plan_confirmed: false`, `execute_completed: false`, `verify_completed: false`, `current_step: discuss`
- **Back to plan**: Set `plan_completed: false`, `plan_confirmed: false`, `execute_completed: false`, `verify_completed: false`, `current_step: research` (or `discuss` if research wasn't done)

### 4. Preserve files

Do NOT delete any existing files in `.dev/current/`. They serve as reference for the user when revising.

### 5. Confirm

Tell the user which step they've rolled back to and what command to run next.
