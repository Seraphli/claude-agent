---
name: ca-status
description: Shows current workflow status including step progress and worktree info. Use when checking workflow progress.
---

# /ca:status — Show Workflow Status

**CRITICAL — Code Modification Policy**: Read-only display command. Do NOT modify any files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Steps

### 1. Resolve workflow and read status

Determine which workflow to display using this priority:

1. **Context inference**: If the current conversation has already been working with a specific workflow, use that workflow ID.
2. **Single workflow**: Run `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. If exactly one workflow exists, use it automatically.
3. **Multiple workflows**: If multiple workflows exist, present them to the user and ask:
   - `AskUserQuestion`: header "[W.Workflow]", question "Which workflow status do you want to see?", options: list each workflow (label: workflow ID, description: "<workflow_type>, step: <current_step>")
4. **No workflows**: Tell the user to run `/ca:new` or `/ca:quick` first and stop.

After resolving `<active_id>`:

Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root> --workflow-id <active_id>`.
- If output contains `"error"`, tell the user to run `/ca:new` first and stop.

### 2. Display status

Use the parsed JSON to display: active workflow ID, current step, completed/pending steps, recommended next action.

If STATUS.md contains `worktree_path`:
- Display: Worktree: `<worktree_path>` (branch: `<branch_name>`, base: `<base_branch>`)
- Check worktree exists: `test -d <worktree_path>`. If not, show warning: "⚠ Worktree directory does not exist".
If STATUS.md contains `branch_name` but NOT `worktree_path` (legacy):
- Display: Branch: `<branch_name>` (base: `<base_branch>`)
- Run `git branch --show-current` and compare with `branch_name`. If mismatch, show warning.

### 4. Show available files

Check which of these files exist and show their status:
- `.ca/workflows/<active_id>/BRIEF.md` — initial brief collected?
- `.ca/workflows/<active_id>/REQUIREMENT.md` — requirement defined?
- `.ca/workflows/<active_id>/rounds/0/PLAN.md` — plan created?
- `.ca/workflows/<active_id>/rounds/0/SUMMARY.md` — execution done?
- `.ca/workflows/<active_id>/VERIFY.csv` — verification ledger?
- `.ca/workflows/<active_id>/TRACKING.md` — tracking doc?
- `.ca/workflows/<active_id>/rounds/0/TASKS.csv` — task ledger?

### 5. Suggest next step

Based on the current state, suggest the logical next command to run.

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.
