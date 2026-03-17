---
name: ca-finish
description: Wraps up a workflow with version bump, branch merge, and archive. Use when verification has passed.
---

# /ca:finish — Wrap Up Workflow

**CRITICAL — Code Modification Policy**: This command handles git operations only (commit, merge, archive). Do NOT modify source code.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `verify_completed: true` from the parsed JSON. If not, tell the user to run `/ca:verify` first. **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. Gitignore Check

Read `track_ca_files` from the config JSON already loaded.

**Pre-check — Are CA files in uncommitted changes?**

Run `git status --porcelain` and check if any file paths match `.ca/` or `.claude/rules/ca`. If NO CA-related files are in the uncommitted changes, **skip the entire Gitignore Check** and proceed to step 2. Only continue with pattern checking if CA-related files are actually present.

Define the CA gitignore patterns:
- `.ca/` pattern: `.ca/`
- `.claude/rules/ca*` pattern: `.claude/rules/ca*`

Based on `track_ca_files`:
- `none`: both patterns should be IN `.gitignore`
- `all`: neither should be in `.gitignore`
- `.ca/`: `.ca/` tracked, `.claude/rules/ca*` ignored
- `.claude/rules/ca*`: reverse

Read `.gitignore` (create if needed). Check patterns.

**CRITICAL — Pattern-by-Pattern Verification**: You MUST check EACH pattern individually against the `.gitignore` file content. For `track_ca_files: none`, verify that BOTH `.ca/` AND `.claude/rules/ca*` are present as separate lines. Do NOT assume that `.claude/` covers `.claude/rules/ca*`. A parent directory entry like `.claude/` in .gitignore is NOT equivalent to the specific pattern `.claude/rules/ca*`. Report any missing pattern.

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

### 2. Git commit and merge

**Conventional Commit format** (https://www.conventionalcommits.org/):

```
<type>[(<scope>)][!]: <description>

[optional body]

[optional footer(s)]
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`.

- `!` after type/scope indicates a breaking change.
- `BREAKING CHANGE:` in footer also indicates a breaking change.

**Semver version bump** (https://semver.org/) — derived from the confirmed commit type:
- `feat!` or `BREAKING CHANGE:` footer → major (X.0.0)
- `feat` → minor (x.Y.0)
- All other types (`fix`, `refactor`, `docs`, `chore`, `perf`, `test`, `style`, `ci`, `build`) → patch (x.y.Z)

Find the project's version location. Search in order:
1. Known version files: `package.json`, `pyproject.toml`, `Cargo.toml`, `version.txt`, `VERSION`
2. If none found, use Grep to search for version patterns in source code
3. If still not found, ask the user where the version is defined

Read from the config JSON already loaded:
- `use_branches`
- `merge_strategy`
- `auto_delete_branch`

Read STATUS.md for `branch_name` and `base_branch`.

**If `use_branches` is `true` AND `branch_name` exists** (branch mode):

#### 2a. Ensure branch changes are committed
1. `git status --porcelain` — check for uncommitted changes. If no changes, skip to 2b.
2. **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "Commit", question "There are uncommitted changes on the branch. Commit them before merge?", options "Yes, commit"/"No, skip".
3. If yes:
   - Run `git diff --stat` and `git status` to gather info.
   - Generate commit message: `<type>: <concise title>` with body listing each change (reference PLAN.md and SUMMARY.md).
   - **CRITICAL — Show full file list**: Display the complete `git diff --stat` output (every file line, NOT just the summary line "N files changed") AND the commit message to the user:
     ```
     Files to commit:
     <full git diff --stat output, every line>

     Commit message:
     <type>: <concise title>

     <body>
     ```
   **CRITICAL**: The header parameter MUST be exactly "Confirm". `AskUserQuestion`: header "Confirm", question "Commit with this message?", options "Yes"/"Revise".
   - If **Revise**: let user edit the message, re-confirm.
   - Stage specific files and commit (no `git add -A`).
4. If no: proceed to step 2b.

#### 2b. Merge to base branch
1. Switch to base branch: `git checkout <base_branch>`.
2. Based on `merge_strategy`:
   - `squash`: Run `git merge --squash <branch_name>`. Then:
     1. Generate a commit message from PLAN.md + SUMMARY.md following conventional commit format.
     2. Derive the semver bump type from the commit type. Calculate the new version number.
     3. Run `git diff --stat` to get the file list. Show to the user:
        ```
        Files to merge:
        <full git diff --stat output, every line>

        Commit message:
        <type>[(<scope>)][!]: <description>

        <body>

        Version bump: <old> → <new> (<bump type>)
        ```
     4. **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "Commit", question "Confirm the merge commit and version bump?", options "Confirm"/"Revise".
        - If **Revise**: let user edit the message and/or version bump, re-confirm.
     5. After confirmation: bump the version in the project files, then stage all changes and run `git commit` with the confirmed message.
   - `merge`:
     1. Generate a merge commit message following conventional commit format.
     2. Derive the semver bump type. Calculate the new version number.
     3. Run `git diff --stat` to get the file list. Show to the user:
        ```
        Files to merge:
        <full git diff --stat output, every line>

        Commit message:
        <type>[(<scope>)][!]: <description>

        <body>

        Version bump: <old> → <new> (<bump type>)
        ```
     4. **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "Commit", question "Confirm the merge commit and version bump?", options "Confirm"/"Revise".
        - If **Revise**: let user edit, re-confirm.
     5. After confirmation: bump the version in the project files, stage version changes, commit version bump, then run `git merge <branch_name> --no-ff -m "<confirmed message>"`.
3. If merge conflict occurs: warn user, tell them to resolve manually, and stop. Do not proceed to step 2c or later steps.

#### 2c. Delete branch
1. If `auto_delete_branch` is `true`: Run `git branch -d <branch_name>`. Inform user branch was deleted.
2. If `auto_delete_branch` is `false`: Keep branch, inform user.

**If `use_branches` is `false` OR `branch_name` does not exist** (non-branch mode):

Use original commit logic:
**CRITICAL — Two-Step Confirmation Required**: The commit decision (header "Commit") and the commit message confirmation (header "Confirm") MUST be two separate AskUserQuestion calls. Do NOT combine them into a single question. Always ask "Commit" first, wait for response, then ask "Confirm".

- **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "Commit", question "Would you like to commit these changes?", options "Yes, commit"/"No, skip".
- If yes:
  1. `git diff --stat` to gather info.
  2. Generate a commit message following conventional commit format.
  3. Derive the semver bump type. Calculate the new version number.
  4. **CRITICAL — Show full file list**: Display the complete `git diff --stat` output AND the commit message:
     ```
     Files to commit:
     <full git diff --stat output, every line>

     Commit message:
     <type>[(<scope>)][!]: <description>

     <body>

     Version bump: <old> → <new> (<bump type>)
     ```
  5. **CRITICAL**: The header parameter MUST be exactly "Confirm". `AskUserQuestion`: header "Confirm", question "Confirm the commit and version bump?", options "Confirm"/"Revise".
     - If **Revise**: let user edit the message and/or version bump, re-confirm.
  6. After confirmation: bump the version in the project files, stage specific files, commit with the confirmed message.
- If no: proceed to step 3.

#### 2d. Write status_note

After the commit/merge step completes (regardless of branch/non-branch mode), update STATUS.md:
- Set `status_note` to a summary of what was committed, e.g.: "Workflow finished. Committed as: <type>: <description>. Version bumped to <version>."
- If user skipped the commit: set `status_note` to "Workflow finished. No commit made. Archived to history."

### 3. Update todo

**CRITICAL — You MUST actually read the file**: Use the Read tool to read `.ca/workflows/<active_id>/BRIEF.md` NOW. Do NOT skip this step or assume you already know the contents. Parse the file content and check if it contains a `linked_todo: <todo text>` line. There may be multiple `linked_todo:` lines — process ALL of them.
If it does:
  **IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `todos.md`. NEVER use Bash commands to write to this file.
  a. Read `.ca/todos.md`.
  b. Find the matching uncompleted todo item (under `# Todo List`, matching the exact text).
  c. Mark it as completed: change `- [ ]` to `- [x]`.
  d. Update the time tag: If the line has `> Added: <date>`, change it to `> Added: <date> | Completed: YYYY-MM-DD` (use today's date).
  e. Move the completed todo item to the `# Archive` section at the bottom of the file.
  f. Save the updated `.ca/todos.md`.

### 4. Archive and cleanup

1. Create archive directory: `.ca/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
2. Move all files from `.ca/workflows/<active_id>/` to the archive directory (including STATUS.md, REQUIREMENT.md, PLAN.md, SUMMARY.md, BRIEF.md, CRITERIA.md, VERIFY-REPORT.md, rounds/ directory if exists, and any other files).
3. Remove the `.ca/workflows/<active_id>/` directory after archiving. If other workflows exist in `.ca/workflows/`, set `active.md` to one of them. If no workflows remain, delete `.ca/active.md`.

Tell the user the workflow cycle is complete.
