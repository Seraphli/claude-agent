# /ca:status — Show Workflow Status

Read config (use Read tool, not search/glob): `.ca/config.md` (workspace) → `~/.claude/ca/config.md` (global) → `~/.claude/ca/references/config-defaults.md` (defaults).

## Steps

### 1. Read active workflow ID

Read `.ca/active.md` to get the active workflow ID. If `.ca/active.md` doesn't exist, tell the user to run `/ca:new` first.

### 2. Check initialization

If `.ca/workflows/<active_id>/STATUS.md` doesn't exist, tell the user to run `/ca:new` first.

### 3. Read and display status

Read STATUS.md and display: active workflow ID, current step, completed/pending steps, recommended next action.

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
