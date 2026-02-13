# /ca:verify — Verify Results and Commit

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `execute_completed: true`. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

You are the verification orchestrator. You delegate the actual verification to the `ca-verifier` agent running in a **fresh context** to avoid confirmation bias.

### 1. Read context

Read these files and collect their full content:
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick`)
- `.ca/workflows/<active_id>/PLAN.md`
- `.ca/workflows/<active_id>/SUMMARY.md`
- `.ca/workflows/<active_id>/CRITERIA.md` (if exists — the authoritative success criteria)

Parse the criteria into two groups based on `[auto]` and `[manual]` tags. Within each group, note the list structure (ordered = sequential, unordered = parallel) for execution planning.

### 2. Resolve model for ca-verifier

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-verifier_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `~/.claude/ca/references/model-profiles.md` and look up the model for `ca-verifier` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Execute auto verification

#### 3a. Parse auto criteria structure

Read the `[auto]` section from CRITERIA.md. Check the list structure:
- If **unordered list** with multiple items that can be split: go to 3c (parallel verification).
- Otherwise: go to 3b (single verifier).

#### 3b. Single verifier

Launch a single `ca-verifier` agent with all `[auto]` criteria. The agent verifies each criterion and returns a report.

#### 3c. Parallel verification (optional)

Read `max_concurrency` from config (default: `4`). If the number of parallel groups exceeds `max_concurrency`, split into batches of `max_concurrency` size and execute batches sequentially. For each batch (or all groups if within limit), launch multiple `ca-verifier` agents **in the same message**, each handling a subset of `[auto]` criteria (based on the unordered list grouping). Each agent receives:
- Its assigned criteria
- All context files (REQUIREMENT.md/BRIEF.md, PLAN.md, SUMMARY.md)
- The project root path
- A unique output file path: `VERIFY-verifier-{N}.md`

Wait for all agents to complete, then merge reports.

#### 3d. Handle auto results

If all auto criteria PASS: proceed to step 3e (manual verification).

If any auto criteria FAIL:

Check `batch_mode` in STATUS.md:

**If `batch_mode: true`**:
- Do NOT retry or trigger fix. Report the failures and return failure status immediately.
- The batch orchestrator (batch.md) will handle rollback and continue to the next workflow.

**If `batch_mode` is false or not set (normal mode)**:
1. Report the failures to the user.
2. Use `AskUserQuestion` with:
   - header: "Fix"
   - question: "Auto verification failed. Would you like to auto-fix and retry?"
   - options:
     - "Yes, fix" — "Auto-fix and retry verification"
     - "No, stop" — "Stop and review manually"
3. If **Yes, fix**:
   - Increment retry counter (track in `.ca/workflows/<active_id>/STATUS.md` as `verify_retry_count`).
   - If retry count > 3: Stop and tell the user: "Auto verification has failed 3 times. Please review the failures and decide how to proceed." Suggest `/ca:fix`.
   - If retry count <= 3:
     - Reset `.ca/workflows/<active_id>/STATUS.md`: set `plan_completed: false`, `plan_confirmed: false`, `execute_completed: false`, `verify_completed: false`
     - Add a "## Fix Notes" section to `.ca/workflows/<active_id>/PLAN.md` describing what failed and needs fixing
     - Execute `Skill(ca:plan)` to enter fix mode
4. If **No, stop**: Stop and suggest `/ca:fix` for manual intervention.

#### 3e. Manual verification

If `batch_mode: true` in STATUS.md: skip manual verification entirely and proceed to step 4.

Present all `[manual]` criteria to the user one at a time. For each:
- Describe what needs to be verified
- Use `AskUserQuestion` to ask the user to confirm PASS or FAIL
- Record the result

After all manual criteria are verified, proceed to step 4.

### 4. Present verification report

Display the report with auto and manual sections:

```
## Verification Report

### Auto Results
| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | ... | PASS/FAIL | ... |

### Manual Results
| # | Criterion | Status | User Confirmation |
|---|-----------|--------|-------------------|
| 1 | ... | PASS/FAIL | ... |

### Overall: PASS/FAIL
```

### 5. MANDATORY CONFIRMATION — User Acceptance

If `batch_mode: true` in STATUS.md: skip user acceptance (auto criteria all passed = accepted) and proceed to gitignore check.

Use `AskUserQuestion` with:
- header: "Results"
- question: "Do you accept these results?"
- options:
  - "Accept" — "Results are satisfactory"
  - "Reject" — "Results need work"

- If **Reject**: Ask what's wrong. Suggest running `/ca:fix` to go back to an earlier step.
- If **Accept**: Proceed to gitignore check.

### 6. Gitignore Check

If `batch_mode: true` in STATUS.md: skip gitignore check entirely and proceed to git commit.

Read `track_ca_files` from config (default: `none`).

Define the CA gitignore patterns:
- `.ca/` pattern: `.ca/`
- `.claude/rules/ca*` pattern: `.claude/rules/ca*`

Determine which patterns to check based on `track_ca_files`:
- `none`: ALL patterns should be IN `.gitignore` (ensure exclusion)
- `all`: ALL patterns should NOT be in `.gitignore` (ensure tracking)
- `.ca/`: `.ca/` should NOT be in `.gitignore`; `.claude/rules/ca*` should be in `.gitignore`
- `.claude/rules/ca*`: `.claude/rules/ca*` should NOT be in `.gitignore`; `.ca/` should be in `.gitignore`

Check if `.gitignore` exists in project root. If not, and patterns need to be added, it will be created.

Read `.gitignore` (if exists) and check for each pattern.

For patterns that should be in `.gitignore` but are missing:
- Use `AskUserQuestion`:
  - header: "Gitignore"
  - question: "`.gitignore` is missing CA entries: <list>. Add them?"
  - options:
    - "Yes, add" — "Add missing entries to .gitignore"
    - "No, skip" — "Leave .gitignore as is"
- If **Yes, add**: Append missing patterns to `.gitignore`.

For patterns that should NOT be in `.gitignore` but are present:
- Use `AskUserQuestion`:
  - header: "Gitignore"
  - question: "`.gitignore` contains CA entries that should be removed for version control: <list>. Remove them?"
  - options:
    - "Yes, remove" — "Remove entries from .gitignore"
    - "No, skip" — "Leave .gitignore as is"
- If **Yes, remove**: Remove matching lines from `.gitignore`.

After any changes, proceed to the next step.

### 7. Git Commit Confirmation

If `batch_mode: true` in STATUS.md:
- Run `git diff --stat` and `git status` to gather file information.
- Generate a commit message following the same format (type: title + detail body).
- Stage the relevant files and commit directly without asking the user.
- Proceed to archiving.
- Do NOT use `AskUserQuestion` — commit automatically.

If `batch_mode` is false or not set: (existing logic unchanged)

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

### 8. Archive and cleanup

After verification (regardless of commit decision):

1. **Check for linked todo**:
   - Read `.ca/workflows/<active_id>/BRIEF.md` and check if it contains a `linked_todo: <todo text>` line.
   - If it does:
     **IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.
     a. Read `.ca/todos.md`.
     b. Find the matching uncompleted todo item (under `# Todo List`, matching the exact text).
     c. Mark it as completed: change `- [ ]` to `- [x]`. (If the workflow was rejected/cancelled, mark as `- [-]` instead.)
     d. Update the time tag: If the line has `> Added: <date>`, change it to `> Added: <date> | Completed: YYYY-MM-DD` (or `| Cancelled: YYYY-MM-DD` if cancelled). Use today's date.
     e. Move the completed todo item to the `# Archive` section at the bottom of the file.
     f. Save the updated `.ca/todos.md`.

2. Create archive directory: `.ca/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
3. Move all files from `.ca/workflows/<active_id>/` to the archive directory (including STATUS.md, REQUIREMENT.md, RESEARCH.md if exists, PLAN.md, SUMMARY.md, BRIEF.md, CRITERIA.md if exists).
4. Remove the `.ca/workflows/<active_id>/` directory after archiving. If other workflows exist in `.ca/workflows/`, set `active.md` to one of them. If no workflows remain, delete `.ca/active.md`.

Tell the user the workflow cycle is complete.
