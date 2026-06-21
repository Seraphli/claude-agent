---
name: ca-finish
description: Wraps up a workflow with version bump, worktree merge, and archive. Use when verification has passed.
disable-model-invocation: true
---

**RESTRICTION: This command can ONLY be invoked directly by the user. It MUST NOT be called by other agents, skills, or automated processes. If you are an agent executing a workflow, STOP — do not proceed with finish. Only the human user can authorize finish.**

# /ca:finish — Wrap Up Workflow

**CRITICAL — Code Modification Policy**: This command handles git operations only (commit, merge, archive). Do NOT modify source code.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Prerequisites

### Resolve workflow ID

Determine which workflow to operate on using this priority:

1. **Context inference**: If the current conversation has already been working with a specific workflow (e.g., you just ran `/ca:quick` or `/ca:plan` for it earlier in this session), use that workflow ID.
2. **Single workflow**: Run `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. If exactly one workflow exists, use it automatically.
3. **Multiple workflows**: If multiple workflows exist, present them to the user and ask which one to operate on:
   - `AskUserQuestion`: header "[W.Workflow]", question "Which workflow do you want to finish?", options: list each workflow (label: workflow ID, description: "<workflow_type>, step: <current_step>")
4. **No workflows**: If no workflows exist, tell the user to run `/ca:new` or `/ca:quick` first and stop.

After resolving `<active_id>`:

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root> --workflow-id <active_id>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `verify_completed: true` from the parsed JSON. If not, tell the user to run `/ca:verify` first. **Stop immediately.**

### 0. Task cleanup and initialization

1. Call `TaskList` to get all existing tasks.
2. If no tasks exist, skip to step 5.
3. If ALL tasks are `completed`: call `TaskUpdate` with `status: "deleted"` for each task.
4. If any task is NOT `completed` (pending or in_progress):
   a. Call `TaskGet` for each uncompleted task.
   b. Analyze possible causes by cross-referencing with STATUS.md (e.g., session interrupted, phase skipped, abnormal exit).
   c. Present to user: list each uncompleted task with subject, status, and possible cause.
   d. `AskUserQuestion`: header "[W.Tasks]", question "There are uncompleted tasks from the previous phase. How to proceed?", options:
      - "Clear and continue" — "Delete all old tasks and start current phase"
      - "Stop" — "Pause to investigate the previous phase's issues"
   e. If "Clear and continue": call `TaskUpdate` with `status: "deleted"` for ALL tasks.
   f. If "Stop": stop current command immediately.
5. Create initial tasks:
   - `TaskCreate`: subject "Gitignore check", activeForm "Checking gitignore"
   - `TaskCreate`: subject "Commit & merge", activeForm "Committing and merging"
   - `TaskCreate`: subject "Version bump", activeForm "Bumping version"
   - `TaskCreate`: subject "Update todo", activeForm "Updating todo"
   - `TaskCreate`: subject "Archive workflow", activeForm "Archiving workflow"

Mark "Gitignore check" as `in_progress`.

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
  - header: "[F.Gitignore]"
  - question: "`.gitignore` is missing CA entries: <list>. Add them?"
  - options:
    - "Yes, add" — "Add missing entries to .gitignore"
    - "No, skip" — "Leave .gitignore as is"
- If **Yes, add**: Append missing patterns to `.gitignore`.

For patterns that should NOT be in `.gitignore` but are present:
- Use `AskUserQuestion`:
  - header: "[F.Gitignore]"
  - question: "`.gitignore` contains CA entries that should be removed for version control: <list>. Remove them?"
  - options:
    - "Yes, remove" — "Remove entries from .gitignore"
    - "No, skip" — "Leave .gitignore as is"
- If **Yes, remove**: Remove matching lines from `.gitignore`.

Mark "Gitignore check" as `completed`. Mark "Commit & merge" as `in_progress`.

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

**Note (informational)**: When finishing the workflow that introduces the round-structure change (rounds/, VERIFY.csv, TRACKING.md, ca-csv.js, etc.), that is a breaking change → use `feat!` with a `BREAKING CHANGE:` footer, which triggers a MAJOR bump. The conventional-commit/semver logic above already derives this automatically from the commit type.

Find the project's version location. Search in order:
1. Known version files: `package.json`, `pyproject.toml`, `Cargo.toml`, `version.txt`, `VERSION`
2. If none found, use Grep to search for version patterns in source code
3. If still not found, ask the user where the version is defined

Read from the config JSON already loaded:
- `use_worktrees`
- `merge_strategy`
- `auto_delete_worktree`

Read STATUS.md for `branch_name`, `base_branch`, and `worktree_path`.

**If `use_worktrees` is `true` AND `branch_name` exists** (worktree mode):

#### 2a. Ensure branch changes are committed
1. `git -C <worktree_path> status --porcelain` — check for uncommitted changes. If no changes, skip to 2b.
2. **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "[F.Commit]", question "There are uncommitted changes on the branch. Commit them before merge?", options "Yes, commit"/"No, skip".
3. If yes:
   - Run `git -C <worktree_path> diff --stat` and `git -C <worktree_path> status` to gather info.
   - Generate commit message: `<type>: <concise title>` with body listing each change (reference PLAN.md and SUMMARY.md).
   - **CRITICAL — Show full file list**: Display the complete `git diff --stat` output (every file line, NOT just the summary line "N files changed") AND the commit message to the user:
     ```
     Files to commit:
     <full git diff --stat output, every line>

     Commit message:
     <type>: <concise title>

     <body>
     ```
   **CRITICAL**: The header parameter MUST be exactly "Confirm". `AskUserQuestion`: header "[F.Confirm]", question "Commit with this message?", options "Yes"/"Revise".
   - If **Revise**: let user edit the message, re-confirm.
   - Stage specific files and commit in the worktree: `git -C <worktree_path> add <files>` and `git -C <worktree_path> commit -m "..."`.
4. If no: proceed to step 2b.

#### 2b. Merge to base branch
1. Verify current branch: `git branch --show-current`. If not `<base_branch>`, **stop and report error**: "Main repo is not on base branch (<base_branch>). Current branch: <actual>. Please switch to <base_branch> manually before running /ca:finish." Do NOT auto-checkout — worktree mode guarantees the main repo stays on base branch.
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
     4. **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "[F.Commit]", question "Confirm the merge commit and version bump?", options "Confirm"/"Revise".
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
     4. **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "[F.Commit]", question "Confirm the merge commit and version bump?", options "Confirm"/"Revise".
        - If **Revise**: let user edit, re-confirm.
     5. After confirmation: bump the version in the project files, stage version changes, commit version bump, then run `git merge <branch_name> --no-ff -m "<confirmed message>"`.
3. If merge conflict occurs: warn user, tell them to resolve manually, and stop. Do not proceed to step 2c or later steps.

#### 2b-multi. Multi-repo merge (if project_worktrees exists)

Read `project_worktrees` from STATUS.md. If present:
1. Parse the comma-separated `label:original_path:worktree_path` triples.
2. For each repo:
   b. First verify the original repo is on its base branch: `git -C <original_path> branch --show-current`. Resolve expected base: `git -C <original_path> rev-parse --verify main 2>/dev/null` → `main`, else `master`. If current branch doesn't match, **stop and report error**.
   c. Based on `merge_strategy`:
        - `squash`: `git -C <original_path> merge --squash ca/<workflow-id> && git -C <original_path> commit -m "<same commit message as main repo>"`
        - `merge`: `git -C <original_path> merge ca/<workflow-id> --no-ff -m "<same commit message>"`
   d. Remove worktree: `git -C <original_path> worktree remove <worktree_path>`
   e. If `auto_delete_worktree` is true:
        - `squash`: `git -C <original_path> branch -D ca/<workflow-id>`
        - `merge`: `git -C <original_path> branch -d ca/<workflow-id>`
3. Report which repos were merged.

#### 2c. Delete branch
1. If `auto_delete_worktree` is `true`:
   - First remove the worktree (if it still exists): `git worktree remove <worktree_path>`
   - Then delete the branch:
     - If `merge_strategy` is `squash`: Run `git branch -D <branch_name>` (squash merge does not preserve original branch commits, so `-d` reachability check fails; `-D` is safe because the squash commit already contains all changes).
     - If `merge_strategy` is `merge`: Run `git branch -d <branch_name>`.
   - Inform user worktree was removed and branch was deleted.
2. If `auto_delete_worktree` is `false`: Keep worktree and branch, inform user.

**If `use_worktrees` is `false` OR `branch_name` does not exist** (non-worktree mode):

Use original commit logic:
**CRITICAL — Two-Step Confirmation Required**: The commit decision (header "[F.Commit]") and the commit message confirmation (header "[F.Confirm]") MUST be two separate AskUserQuestion calls. Do NOT combine them into a single question. Always ask "Commit" first, wait for response, then ask "Confirm".

- **CRITICAL**: The header parameter MUST be exactly "Commit". `AskUserQuestion`: header "[F.Commit]", question "Would you like to commit these changes?", options "Yes, commit"/"No, skip".
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
  5. **CRITICAL**: The header parameter MUST be exactly "Confirm". `AskUserQuestion`: header "[F.Confirm]", question "Confirm the commit and version bump?", options "Confirm"/"Revise".
     - If **Revise**: let user edit the message and/or version bump, re-confirm.
  6. After confirmation: bump the version in the project files, stage specific files, commit with the confirmed message.
- If no: proceed to step 3.

Mark "Commit & merge" as `completed`. Mark "Version bump" as `completed`. Mark "Update todo" as `in_progress`.

#### 2d. Write status_note

After the commit/merge step completes (regardless of branch/non-branch mode), update STATUS.md:
- Set `status_note` to a summary of what was committed, e.g.: "Workflow finished. Committed as: <type>: <description>. Version bumped to <version>."
- If user skipped the commit: set `status_note` to "Workflow finished. No commit made. Archived to history."

### 2e. Regenerate project-level map

If the user committed/merged in step 2 (not skipped), regenerate `.ca/map.md` to reflect the current post-merge repo state:

1. Scan the project root directory using Glob/Read tools (skip `.git/`, `node_modules/`, `.ca/`, and other common ignored directories).
2. Write `.ca/map.md` directly with the standard map format (Project Overview, Directory Structure, Key Files). **Do NOT use `Skill(ca:map)` — Skill calls will terminate the current session.**

If the user skipped the commit, skip this step — the project-level map does not need updating since no code was merged.

### 3. Update todo

**CRITICAL — You MUST actually read the file**: Use the Read tool to read `.ca/workflows/<active_id>/BRIEF.md` NOW. Do NOT skip this step or assume you already know the contents. Parse the file content and check if it contains a `linked_todo: <todo text>` line. There may be multiple `linked_todo:` lines — process ALL of them.
If it does:
  **IMPORTANT**: Only use `Read` and `Write`/`Edit` tools to operate on `.ca/todos.md` and `.ca/todos-archive.md`. NEVER use Bash commands to write to these files.

  Before reading `.ca/todos.md`, if the file contains a line matching `^# Archive`, follow `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/todos-migration.md` to migrate to the split layout, then continue.

  a. Read `.ca/todos.md`.
  b. Find the matching uncompleted todo item (matching the exact text).
  c. Mark it as completed: change `- [ ]` to `- [x]`.
  d. Update the time tag: If the line has `> Added: <date>`, change it to `> Added: <date> | Completed: YYYY-MM-DD` (use today's date).
  e. Remove the completed todo item (with all its blockquote lines) from `.ca/todos.md`.
  f. Append the completed todo item to `.ca/todos-archive.md` under the `# Archive` header. If `.ca/todos-archive.md` does not exist, create it with a single `# Archive` header line followed by the item. Save both files.

Mark "Update todo" as `completed`. Mark "Archive workflow" as `in_progress`.

### 3b. Git-flip TASKS.csv (non-worktree only)

**Skip this step if `use_worktrees` is `true`** — worktree and instant workflows already set `git=done` on each task at execute time.

For non-worktree standard/quick/write workflows only: after the commit decision in §2 has been resolved, update every round's `rounds/<r>/TASKS.csv` to reflect the final git outcome:

1. Determine the git outcome from §2:
   - If the user confirmed a commit: outcome is `done`
   - If the user skipped the commit: outcome is `skipped`
2. Enumerate all round directories under `.ca/workflows/<active_id>/rounds/` (round 0 plus any fix rounds).
3. For each `rounds/<r>/TASKS.csv`:
   a. Collect every task id in that CSV:
      ```
      node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js get --file .ca/workflows/<active_id>/rounds/<r>/TASKS.csv --json
      ```
      Read each row's `id` and join them comma-separated (e.g. `1,2,3`).
   b. Flip them all in a single call (`--id` accepts a comma-separated list):
      ```
      node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update --file .ca/workflows/<active_id>/rounds/<r>/TASKS.csv --id <id1,id2,...> --field git --value <done|skipped>
      ```

**CRITICAL**: This step MUST complete before §4 archiving moves `rounds/` to history. The archived TASKS.csv files must reflect the correct `git` state.

### 4. Archive and cleanup

1. Create archive directory: `.ca/history/NNNN-slug/` where NNNN is a zero-padded sequence number and slug is derived from the requirement goal.
2. Move all files from `.ca/workflows/<active_id>/` to the archive directory (including STATUS.md, REQUIREMENT.md, BRIEF.md, SPEC.md, VERIFY.csv, TRACKING.md, the entire `rounds/` directory — which holds round 0's PLAN.md/TASKS.csv/SUMMARY.md/VERIFY-REPORT.md/ISSUES.md and every fix round — and any other files). Moving the whole workflow directory preserves `rounds/0/` intact.
3. Remove the `.ca/workflows/<active_id>/` directory after archiving.

**Do NOT move or archive `.ca/docs/` (CONTEXT.md, adr/) — it is project-level, shared across workflows, and must persist.**

Mark "Archive workflow" as `completed`.

Tell the user the workflow cycle is complete.
