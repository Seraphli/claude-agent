# /ca:finish — Wrap Up Workflow

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values.

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `verify_completed: true`. If not, tell the user to run `/ca:verify` first. **Stop immediately.**

## Behavior

### 1. Bump version

Read `package.json` and determine the version bump type based on the workflow's changes:
- Read `.ca/workflows/<active_id>/REQUIREMENT.md` (or BRIEF.md) and the relevant PLAN.md to understand the nature of changes.
- Determine bump type:
  - Breaking changes → major bump (X.0.0)
  - New feature (`feat`) → minor bump (x.Y.0)
  - Bug fix, refactor, docs, chore → patch bump (x.y.Z)
- Update the `version` field in `package.json`.
- Also update `~/.claude/ca/version` with the new version number.

### 2. Gitignore Check

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
    Where `<type>` is one of: feat, fix, refactor, docs, chore, test.
    The body MUST contain a bulleted list describing each significant change made in this workflow cycle. Reference the PLAN.md implementation steps and SUMMARY.md to generate comprehensive details. Never omit the body.
  - **Display to the user before asking for confirmation**:
    - The full proposed commit message
    - The complete list of files that will be committed
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
