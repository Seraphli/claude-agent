# /ca:fix — Roll Back to a Previous Step

## Prerequisites

Read `.ca/active.md` to get the active workflow ID. If `.ca/active.md` does not exist, tell the user to run `/ca:new` first and stop.

Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

### 1. Show current state

Read `.ca/workflows/<active_id>/STATUS.md` and display where the workflow currently is.

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

Do NOT delete any existing files in `.ca/workflows/<active_id>/`. They serve as reference for the user when revising.

### 5. Update PLAN.md for fix mode (if rolling back to plan)

If the target step is `plan` and `.ca/workflows/<active_id>/PLAN.md` exists:
- Read the current PLAN.md and `.ca/workflows/<active_id>/SUMMARY.md` (if exists)
- Based on the execution summary, mark completed implementation steps with `[x]` prefix
- Mark steps that failed, need modification, or were not reached with `[ ]` prefix
- Add a section at the end of PLAN.md:

```
## Fix Notes

Rolled back to plan on YYYY-MM-DD.
Steps marked [x] were completed before rollback.
Steps marked [ ] need to be re-planned or modified.
The planner should append/update fix steps below, NOT rewrite the entire plan.
```

### 6. Update CRITERIA.md for fix mode (if rolling back to plan)

If `.ca/workflows/<active_id>/CRITERIA.md` exists:
- Read the current CRITERIA.md
- Keep all existing criteria entries intact
- Add a note at the end:

```
## Fix Notes

Rolled back on YYYY-MM-DD. All criteria above must still be verified after fix.
New criteria for fix changes should be appended below this line.
```

### 7. Confirm

Tell the user which step they've rolled back to and what command to run next.

If rolled back to plan, also tell the user: "PLAN.md has been updated with completion markers. When `/ca:plan` runs, it will append/update steps rather than rewriting."
