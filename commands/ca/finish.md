# /ca:finish — Wrap Up Workflow

Read `~/.claude/ca/config.md` (global) then `.ca/config.md` (workspace override).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `verify_completed: true`. If not, tell the user to run `/ca:verify` first. **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (selects "Other"/chat or provides text input), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. Do NOT ignore unselected options and continue with default behavior.

### 1. Bump version

Read `package.json` and REQUIREMENT.md/BRIEF.md + PLAN.md. Determine bump type:
- Breaking → major (X.0.0)
- Feature → minor (x.Y.0)
- Fix/refactor/docs/chore → patch (x.y.Z)

Update `version` in `package.json` and `~/.claude/ca/version`.

### 2. Gitignore Check

Read `track_ca_files` from config (default: `none`).

Define the CA gitignore patterns:
- `.ca/` pattern: `.ca/`
- `.claude/rules/ca*` pattern: `.claude/rules/ca*`

Based on `track_ca_files`:
- `none`: both patterns should be IN `.gitignore`
- `all`: neither should be in `.gitignore`
- `.ca/`: `.ca/` tracked, `.claude/rules/ca*` ignored
- `.claude/rules/ca*`: reverse

Read `.gitignore` (create if needed). Check patterns.

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

### 3. Git Commit

Use `AskUserQuestion` with:
- header: "Commit"
- question: "Would you like to commit these changes?"
- options:
  - "Yes, commit" — "Commit the changes"
  - "No, skip" — "Skip committing"

- If **No, skip**: Tell the user the workflow is complete without committing. Proceed to step 4.
- If **Yes, commit**:
  - Run `git diff --stat` and `git status` to gather file information.
  - Propose a commit message following this format:
    ```
    <type>: <concise title (under 72 chars)>

    - <detail 1: what was changed and why>
    - <detail 2: what was changed and why>
    - ...
    ```
    `<type>`: feat, fix, refactor, docs, chore, test. Body MUST list each significant change (reference PLAN.md and SUMMARY.md). Never omit the body.
  - Show the proposed commit message and file list.
  - `AskUserQuestion`: header "Message", question "Confirm this commit message?", options "Confirm"/"Edit"/"Skip".
    - **Edit**: Let user provide new message.
    - **Confirm**: Stage specific files and commit (no `git add -A`).
    - **Skip**: Skip committing.

### 4. Update todo

Read `.ca/workflows/<active_id>/BRIEF.md` and check if it contains a `linked_todo: <todo text>` line.
If it does:
  **IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.
  a. Read `.ca/todos.md`.
  b. Find the matching uncompleted todo item (under `# Todo List`, matching the exact text).
  c. Mark it as completed: change `- [ ]` to `- [x]`.
  d. Update the time tag: If the line has `> Added: <date>`, change it to `> Added: <date> | Completed: YYYY-MM-DD` (use today's date).
  e. Move the completed todo item to the `# Archive` section at the bottom of the file.
  f. Save the updated `.ca/todos.md`.

### 5. Archive and cleanup

1. Create archive directory: `.ca/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
2. Move all files from `.ca/workflows/<active_id>/` to the archive directory (including STATUS.md, REQUIREMENT.md, PLAN.md, SUMMARY.md, BRIEF.md, CRITERIA.md, VERIFY-REPORT.md, rounds/ directory if exists, and any other files).
3. Remove the `.ca/workflows/<active_id>/` directory after archiving. If other workflows exist in `.ca/workflows/`, set `active.md` to one of them. If no workflows remain, delete `.ca/active.md`.

Tell the user the workflow cycle is complete.
