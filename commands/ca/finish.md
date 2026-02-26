# /ca:finish — Wrap Up Workflow

Read config (use Read tool, not search/glob): `.ca/config.md` (workspace) → `~/.claude/ca/config.md` (global) → `~/.claude/ca/references/config-defaults.md` (defaults).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `verify_completed: true`. If not, tell the user to run `/ca:verify` first. **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. Bump version

Read REQUIREMENT.md/BRIEF.md + PLAN.md. Determine bump type:
- Breaking → major (X.0.0)
- Feature → minor (x.Y.0)
- Fix/refactor/docs/chore → patch (x.y.Z)

Find the project's version location. Search in order:
1. Known version files: `package.json`, `pyproject.toml`, `Cargo.toml`, `version.txt`, `VERSION`
2. If none found, use Grep to search for version patterns in source code (e.g., `Version = "`, `VERSION = "`, `const version`, `var version`, `__version__`)
3. If still not found, ask the user where the version is defined

Update the version at the found location. If multiple locations exist (e.g., `package.json` + `package-lock.json`), update all of them.

### 2. Gitignore Check

Read `track_ca_files` from config: `.ca/config.md` → `~/.claude/ca/config.md` → `~/.claude/ca/references/config-defaults.md`.

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

### 3. Git commit and merge

Read from config (`.ca/config.md` → `~/.claude/ca/config.md` → `~/.claude/ca/references/config-defaults.md`):
- `use_branches`
- `merge_strategy`
- `auto_delete_branch`

Read STATUS.md for `branch_name` and `base_branch`.

**If `use_branches` is `true` AND `branch_name` exists** (branch mode):

#### 3a. Ensure branch changes are committed
1. `git status --porcelain` — check for uncommitted changes. If no changes, skip to 3b.
2. `AskUserQuestion`: header "Commit", question "There are uncommitted changes on the branch. Commit them before merge?", options "Yes, commit"/"No, skip".
3. If yes:
   - Run `git diff --stat` and `git status` to gather info.
   - Generate commit message: `<type>: <concise title>` with body listing each change (reference PLAN.md and SUMMARY.md).
   - Show the diff summary and commit message to the user. `AskUserQuestion`: header "Confirm", question "Commit with this message?", options "Yes"/"Revise".
   - If **Revise**: let user edit the message, re-confirm.
   - Stage specific files and commit (no `git add -A`).
4. If no: proceed to step 3b.

#### 3b. Merge to base branch
1. Switch to base branch: `git checkout <base_branch>`.
2. Based on `merge_strategy`:
   - `squash`: Run `git merge --squash <branch_name>`. Then generate a summary commit message from PLAN.md + SUMMARY.md (format: `<type>: <concise title>` with body). Run `git commit` with the generated message.
   - `merge`: Run `git merge <branch_name> --no-ff -m "<message>"` with generated message.
3. If merge conflict occurs: warn user, tell them to resolve manually, and stop. Do not proceed to step 3c or later steps.

#### 3c. Delete branch
1. If `auto_delete_branch` is `true`: Run `git branch -d <branch_name>`. Inform user branch was deleted.
2. If `auto_delete_branch` is `false`: Keep branch, inform user.

**If `use_branches` is `false` OR `branch_name` does not exist** (non-branch mode):

Use original commit logic:
- `AskUserQuestion`: header "Commit", question "Would you like to commit these changes?", options "Yes, commit"/"No, skip".
- If yes: `git diff --stat`, generate message, confirm with user, stage specific files, commit.
- If no: proceed to step 4.

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
