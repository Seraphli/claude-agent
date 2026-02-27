# /ca:fix — Start Fix Round

Read config by running: `node ~/.claude/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ~/.claude/ca/scripts/ca-status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `execute_completed: true` from the parsed JSON. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. Read current state

Read `.ca/workflows/<active_id>/STATUS.md` and display:
- Current `fix_round` value (default: 0 if not present)
- Current workflow state

### 2. Determine fix round

Read `fix_round` from STATUS.md (default: 0 if not present).
Set N = fix_round + 1.

### 3. Create round directory

Create `.ca/workflows/<active_id>/rounds/<N>/` directory.

### 4. Collect issues

**Read VERIFY-REPORT.md** from the previous location:
- If N == 1: read `.ca/workflows/<active_id>/VERIFY-REPORT.md`
- If N > 1: read `.ca/workflows/<active_id>/rounds/<N-1>/VERIFY-REPORT.md`

If VERIFY-REPORT.md exists, present its contents to the user as the known issues.
If VERIFY-REPORT.md does not exist, inform the user no verification report was found.

**Ask for additional feedback**: Use `AskUserQuestion` with:
- header: "Issues"
- question: "Are there additional issues beyond the verification report?"
- options:
  - "No additional issues" — "Only fix the issues in the report"
  - "Add issues" — "I have additional feedback"

If **Add issues**: Let the user describe additional issues in conversation. Collect them.

### 5. Write ISSUES.md

Write `.ca/workflows/<active_id>/rounds/<N>/ISSUES.md`:

```markdown
# Issues (Round N)

## From Verification Report
<issues extracted from VERIFY-REPORT.md, or "No verification report found">

## Additional User Feedback
<issues from user, or "None">
```

### 6. Update STATUS.md

Update STATUS.md with:
- `fix_round: <N>`
- `plan_completed: false`
- `plan_confirmed: false`
- `execute_completed: false`
- `verify_completed: false`
- `current_step: fix`

### 7. Confirm

Tell the user the fix round has been set up. Suggest next steps:
- Fix round N has been started
- Issues have been recorded in `rounds/<N>/ISSUES.md`
- `/ca:plan` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
