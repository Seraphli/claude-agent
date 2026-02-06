# /ca:status — Show Workflow Status

Read `.dev/config.md` to determine the user's preferred language. Respond in that language.

## Steps

### 1. Check initialization

If `.dev/current/STATUS.md` doesn't exist, tell the user to run `/ca:init` first.

### 2. Read and display status

Read `.dev/current/STATUS.md` and display the current workflow state in a clear format.

Show:
- Current step in the workflow
- Which steps are completed
- Which steps are pending
- What the next recommended action is

### 3. Show available files

Check which of these files exist and show their status:
- `.dev/current/REQUIREMENT.md` — requirement defined?
- `.dev/current/RESEARCH.md` — research done?
- `.dev/current/PLAN.md` — plan created?
- `.dev/current/SUMMARY.md` — execution done?

### 4. Suggest next step

Based on the current state, suggest the logical next command to run.
