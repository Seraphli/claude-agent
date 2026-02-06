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

### 2. Resolve model for ca-verifier

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-verifier_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `references/model-profiles.md` and look up the model for `ca-verifier` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Launch ca-verifier agent

Use the Task tool with `subagent_type: "ca-verifier"` and the resolved `model` parameter to launch the ca-verifier agent. Pass it:
- The full content of REQUIREMENT.md
- The full content of PLAN.md
- The full content of SUMMARY.md
- The project root path
- Instructions to follow the `ca-verifier` agent prompt

The agent independently checks every success criterion and returns a verification report.

### 4. Present verification report

Display the report to the user:

```
## Verification Report

### Results
| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | ... | PASS/FAIL | ... |

### Overall: PASS/FAIL
```

### 5. MANDATORY CONFIRMATION — User Acceptance

Ask the user: **"Do you accept these results? (yes/no)"**

- If **no**: Ask what's wrong. Suggest running `/ca:fix` to go back to an earlier step.
- If **yes**: Proceed to git commit step.

### 6. Git Commit Confirmation

Ask the user: **"Would you like to commit these changes? (yes/no)"**

- If **no**: Tell the user the workflow is complete without committing. Proceed to archiving.
- If **yes**:
  - Run `git diff --stat` and `git status` to show what will be committed.
  - Propose a commit message.
  - Ask: **"Confirm this commit message? (yes/edit/no)"**
    - If **edit**: Let the user provide a new message.
    - If **yes**: Stage the relevant files and commit (do NOT use `git add -A`; add specific files).
    - If **no**: Skip committing.

### 7. Archive and cleanup

After verification (regardless of commit decision):

1. **Check for linked todo**:
   - Read `.dev/current/BRIEF.md` and check if it contains a `linked_todo: <todo text>` line.
   - If it does:
     a. Read `.dev/todos.md`.
     b. Find the matching uncompleted todo item (under `# Todo List`, matching the exact text).
     c. Mark it as completed: change `- [ ]` to `- [x]`. (If the workflow was rejected/cancelled, mark as `- [-]` instead.)
     d. Update the time tag: If the line has `> Added: <date>`, change it to `> Added: <date> | Completed: YYYY-MM-DD` (or `| Cancelled: YYYY-MM-DD` if cancelled). Use today's date.
     e. Move the completed todo item to the `# Archive` section at the bottom of the file.
     f. Save the updated `.dev/todos.md`.

2. Create archive directory: `.dev/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
3. Copy `REQUIREMENT.md`, `RESEARCH.md` (if exists), `PLAN.md`, `SUMMARY.md`, `BRIEF.md` from `.dev/current/` to the archive.
4. Remove the copied files from `.dev/current/` (keep STATUS.md).
5. Reset STATUS.md to the init state (all completed flags false except init).

Update STATUS.md: `verify_completed: true`, `current_step: done`.

Tell the user the workflow cycle is complete.
