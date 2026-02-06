# /ca:verify — Verify Results and Commit

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

1. Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Read `.dev/current/STATUS.md` and verify `execute_completed: true`. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

You are the verification orchestrator. You delegate the actual verification to the `ca-verifier` agent running in a **fresh context** to avoid confirmation bias.

### 1. Read context

Read these files and collect their full content:
- `.dev/current/REQUIREMENT.md`
- `.dev/current/PLAN.md`
- `.dev/current/SUMMARY.md`

### 2. Launch ca-verifier agent

Use the Task tool with `subagent_type: "general-purpose"` to launch the ca-verifier agent. Pass it:
- The full content of REQUIREMENT.md
- The full content of PLAN.md
- The full content of SUMMARY.md
- The project root path
- Instructions to follow the `ca-verifier` agent prompt

The agent independently checks every success criterion and returns a verification report.

### 3. Present verification report

Display the report to the user:

```
## Verification Report

### Results
| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | ... | PASS/FAIL | ... |

### Overall: PASS/FAIL
```

### 4. MANDATORY CONFIRMATION — User Acceptance

Ask the user: **"Do you accept these results? (yes/no)"**

- If **no**: Ask what's wrong. Suggest running `/ca:fix` to go back to an earlier step.
- If **yes**: Proceed to git commit step.

### 5. Git Commit Confirmation

Ask the user: **"Would you like to commit these changes? (yes/no)"**

- If **no**: Tell the user the workflow is complete without committing. Proceed to archiving.
- If **yes**:
  - Run `git diff --stat` and `git status` to show what will be committed.
  - Propose a commit message.
  - Ask: **"Confirm this commit message? (yes/edit/no)"**
    - If **edit**: Let the user provide a new message.
    - If **yes**: Stage the relevant files and commit (do NOT use `git add -A`; add specific files).
    - If **no**: Skip committing.

### 6. Archive and cleanup

After verification (regardless of commit decision):

1. Create archive directory: `.dev/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
2. Copy `REQUIREMENT.md`, `RESEARCH.md` (if exists), `PLAN.md`, `SUMMARY.md` from `.dev/current/` to the archive.
3. Remove the copied files from `.dev/current/` (keep STATUS.md).
4. Reset STATUS.md to the init state (all completed flags false except init).

Update STATUS.md: `verify_completed: true`, `current_step: done`.

Tell the user the workflow cycle is complete.
