---
name: ca-next
description: Auto-detects the current workflow step and executes the next one. Use when user wants to advance the workflow.
---

# /ca:next — Execute Next Workflow Step

**CRITICAL — Code Modification Policy**: This command routes to the appropriate skill. Does not modify code directly.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:status.js read --project-root <project-root>`. Parse the JSON output.
- If output contains `"error"`, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Read current status

Use the parsed JSON from the prerequisites to determine the current workflow state.

### 2. Determine and execute next step

Based on the status flags and `workflow_type`, determine the next step and execute it using the `Skill` tool:

**For `workflow_type: standard`:**
- If `init_completed: true` and `discuss_completed: false` → Execute `Skill(ca:discuss)`
- If `discuss_completed: true` and `plan_completed: false` → Execute `Skill(ca:plan)`
- If `plan_confirmed: true` and `execute_completed: false` → Execute `Skill(ca:execute)`
- If `execute_completed: true` and `verify_completed: false` → Execute `Skill(ca:verify)`
- If `verify_completed: true` → Execute `Skill(ca:finish)`

**For `workflow_type: quick`:**
- If `init_completed: true` and `plan_completed: false` → Execute `Skill(ca:plan)`
- If `plan_confirmed: true` and `execute_completed: false` → Execute `Skill(ca:execute)`
- If `execute_completed: true` and `verify_completed: false` → Execute `Skill(ca:verify)`
- If `verify_completed: true` → Execute `Skill(ca:finish)`

### 3. Edge cases

- If no STATUS.md exists, tell the user to run `/ca:new` first.
- If the workflow is in an inconsistent state (e.g., plan_completed but not plan_confirmed), tell the user and suggest running the appropriate command.
