# /ca:verify — Verify Results and Commit

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Check `.ca/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Read `.ca/current/STATUS.md` and verify `execute_completed: true`. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

You are the verification orchestrator. You delegate the actual verification to the `ca-verifier` agent running in a **fresh context** to avoid confirmation bias.

### 1. Read context

Read these files and collect their full content:
- `.ca/current/REQUIREMENT.md` (or `.ca/current/BRIEF.md` if `workflow_type: quick`)
- `.ca/current/PLAN.md`
- `.ca/current/SUMMARY.md`
- `.ca/current/CRITERIA.md` (if exists — the authoritative success criteria)

### 2. Resolve model for ca-verifier

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-verifier_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `~/.claude/ca/references/model-profiles.md` and look up the model for `ca-verifier` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Launch ca-verifier agent

Use the Task tool with `subagent_type: "ca-verifier"` and the resolved `model` parameter to launch the ca-verifier agent. Pass it:
- The full content of REQUIREMENT.md (or BRIEF.md if `workflow_type: quick`)
- The full content of PLAN.md
- The full content of SUMMARY.md
- The full content of CRITERIA.md (if exists — this is the authoritative source of success criteria)
- The project root path
- Instructions to follow the `ca-verifier` agent prompt
- Instruct the verifier: If CRITERIA.md exists, use it as the authoritative success criteria list. Verify ALL criteria, including those from previous cycles that were already passing. This ensures fix modifications have not broken previously working functionality.

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

Use `AskUserQuestion` with:
- header: "Results"
- question: "Do you accept these results?"
- options:
  - "Accept" — "Results are satisfactory"
  - "Reject" — "Results need work"

- If **Reject**: Ask what's wrong. Suggest running `/ca:fix` to go back to an earlier step.
- If **Accept**: Proceed to git commit step.

### 6. Git Commit Confirmation

Use `AskUserQuestion` with:
- header: "Commit"
- question: "Would you like to commit these changes?"
- options:
  - "Yes, commit" — "Commit the changes"
  - "No, skip" — "Skip committing"

- If **No, skip**: Tell the user the workflow is complete without committing. Proceed to archiving.
- If **Yes, commit**:
  - Run `git diff --stat` and `git status` to gather file information.
  - Propose a commit message following this format:
    ```
    <type>: <concise title (under 72 chars)>

    - <detail 1: what was changed and why>
    - <detail 2: what was changed and why>
    - ...
    ```
    Where `<type>` is one of: feat, fix, refactor, docs, chore, test.
    The body MUST contain a bulleted list describing each significant change made in this workflow cycle. Reference the PLAN.md implementation steps and SUMMARY.md to generate comprehensive details. Never omit the body — even for small changes, include at least one detail line.
  - **Display to the user before asking for confirmation**:
    - The full proposed commit message
    - The complete list of files that will be committed (from git status/diff output)
  - Use `AskUserQuestion` with:
    - header: "Message"
    - question: "Confirm this commit message?"
    - options:
      - "Confirm" — "Use this message"
      - "Edit" — "I want to change the message"
      - "Skip" — "Don't commit"
    - If **Edit**: Let the user provide a new message.
    - If **Confirm**: Stage the relevant files and commit (do NOT use `git add -A`; add specific files).
    - If **Skip**: Skip committing.

### 7. Archive and cleanup

After verification (regardless of commit decision):

1. **Check for linked todo**:
   - Read `.ca/current/BRIEF.md` and check if it contains a `linked_todo: <todo text>` line.
   - If it does:
     **IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.
     a. Read `.ca/todos.md`.
     b. Find the matching uncompleted todo item (under `# Todo List`, matching the exact text).
     c. Mark it as completed: change `- [ ]` to `- [x]`. (If the workflow was rejected/cancelled, mark as `- [-]` instead.)
     d. Update the time tag: If the line has `> Added: <date>`, change it to `> Added: <date> | Completed: YYYY-MM-DD` (or `| Cancelled: YYYY-MM-DD` if cancelled). Use today's date.
     e. Move the completed todo item to the `# Archive` section at the bottom of the file.
     f. Save the updated `.ca/todos.md`.

2. Create archive directory: `.ca/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
3. Move all files from `.ca/current/` to the archive directory (including STATUS.md, REQUIREMENT.md, RESEARCH.md if exists, PLAN.md, SUMMARY.md, BRIEF.md, CRITERIA.md if exists).
4. Ensure `.ca/current/` is empty after archiving.

Tell the user the workflow cycle is complete.
