# /ca:status — Show Workflow Status

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Steps

### 1. Check initialization

If `.ca/current/STATUS.md` doesn't exist, tell the user to run `/ca:new` first.

### 2. Read and display status

Read `.ca/current/STATUS.md` and display the current workflow state in a clear format.

Show:
- Current step in the workflow
- Which steps are completed
- Which steps are pending
- What the next recommended action is

### 3. Show available files

Check which of these files exist and show their status:
- `.ca/current/BRIEF.md` — initial brief collected?
- `.ca/current/REQUIREMENT.md` — requirement defined?
- `.ca/current/RESEARCH.md` — research done?
- `.ca/current/PLAN.md` — plan created?
- `.ca/current/SUMMARY.md` — execution done?

### 4. Suggest next step

Based on the current state, suggest the logical next command to run.
