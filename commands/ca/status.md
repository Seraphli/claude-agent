---
name: ca-status
description: Shows current workflow status including step progress and branch info. Use when checking workflow progress.
disable-model-invocation: true
---

# /ca:status — Show Workflow Status

**CRITICAL — Code Modification Policy**: Read-only display command. Do NOT modify any files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Steps

### 1. Read active workflow status

Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:status.js read --project-root <project-root>`. Parse the JSON output.
- If output contains `"error"`, tell the user to run `/ca:new` first and stop.

### 2. Display status

Use the parsed JSON to display: active workflow ID, current step, completed/pending steps, recommended next action.

If STATUS.md contains `branch_name`:
- Display: Branch: `<branch_name>` (base: `<base_branch>`)
- Run `git branch --show-current` and compare with `branch_name`. If mismatch, show warning: "⚠ Current git branch does not match workflow branch".

### 4. Show available files

Check which of these files exist and show their status:
- `.ca/workflows/<active_id>/BRIEF.md` — initial brief collected?
- `.ca/workflows/<active_id>/REQUIREMENT.md` — requirement defined?
- `.ca/workflows/<active_id>/PLAN.md` — plan created?
- `.ca/workflows/<active_id>/SUMMARY.md` — execution done?

### 5. Suggest next step

Based on the current state, suggest the logical next command to run.

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.
