# /ca:status — Show Workflow Status

## Steps

### 1. Read active workflow ID

Read `.ca/active.md` to get the active workflow ID. If `.ca/active.md` doesn't exist, tell the user to run `/ca:new` first.

### 2. Check initialization

If `.ca/workflows/<active_id>/STATUS.md` doesn't exist, tell the user to run `/ca:new` first.

### 3. Read and display status

Read `.ca/workflows/<active_id>/STATUS.md` and display the current workflow state in a clear format.

Display the active workflow ID at the top of the status output.

Show:
- Current step in the workflow
- Which steps are completed
- Which steps are pending
- What the next recommended action is

### 4. Show available files

Check which of these files exist and show their status:
- `.ca/workflows/<active_id>/BRIEF.md` — initial brief collected?
- `.ca/workflows/<active_id>/REQUIREMENT.md` — requirement defined?
- `.ca/workflows/<active_id>/PLAN.md` — plan created?
- `.ca/workflows/<active_id>/SUMMARY.md` — execution done?

### 5. Suggest next step

Based on the current state, suggest the logical next command to run.
