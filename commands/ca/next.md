# /ca:next — Execute Next Workflow Step

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Read current status

Read `.dev/current/STATUS.md` and determine the current workflow state.

### 2. Determine and execute next step

Based on the status flags and `workflow_type`, determine the next step and execute it using the `Skill` tool:

**For `workflow_type: standard`:**
- If `init_completed: true` and `discuss_completed: false` → Execute `Skill(ca:discuss)`
- If `discuss_completed: true` and `research_completed: false` → Execute `Skill(ca:research)`
- If `research_completed: true` and `plan_completed: false` → Execute `Skill(ca:plan)`
- If `plan_confirmed: true` and `execute_completed: false` → Execute `Skill(ca:execute)`
- If `execute_completed: true` and `verify_completed: false` → Execute `Skill(ca:verify)`
- If `verify_completed: true` → Tell the user the workflow is complete.

**For `workflow_type: quick`:**
- If `init_completed: true` and `plan_completed: false` → Execute `Skill(ca:plan)`
- If `plan_confirmed: true` and `execute_completed: false` → Execute `Skill(ca:execute)`
- If `execute_completed: true` and `verify_completed: false` → Execute `Skill(ca:verify)`
- If `verify_completed: true` → Tell the user the workflow is complete.

### 3. Edge cases

- If no STATUS.md exists, tell the user to run `/ca:new` first.
- If the workflow is in an inconsistent state (e.g., plan_completed but not plan_confirmed), tell the user and suggest running the appropriate command.
