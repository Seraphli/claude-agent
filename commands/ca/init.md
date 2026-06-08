---
name: ca-init
description: Initializes .ca/project.yaml for multi-repo projects by interactively collecting project name, directories, and rule file paths. Use when user says "init", "初始化项目", or wants to set up a multi-repo project.yaml.
---
# /ca:init — Initialize Project Configuration

**CRITICAL — Code Modification Policy**: This command ONLY creates/overwrites `.ca/project.yaml`. Do NOT read, analyze, or modify source code or any other project files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Purpose

`.ca/project.yaml` declares a multi-repo project: a project name and a list of directories (each a separate git repository) that workflows (`/ca:new`, `/ca:quick`, `/ca:instant`) use to create per-repo worktrees, and that `/ca:execute` uses to pass repo paths (and the contents of any rule files) to executor agents. This command generates that file.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

### 1. Ensure `.ca/` exists

Create the `.ca/` directory if it does not exist (`mkdir -p .ca`).

### 2. Check for existing project.yaml

Check whether `.ca/project.yaml` exists.

If it exists, read it, show the user its current `project_name` and directory list, then use `AskUserQuestion`:
- **CRITICAL**: header MUST be exactly `"Overwrite"`.
- question: "`.ca/project.yaml` already exists. Overwrite it?"
- options:
  - "Overwrite" — "Replace the existing project.yaml with a new one"
  - "Cancel" — "Keep the existing project.yaml unchanged"
- If **Cancel**: Stop immediately. Do NOT modify the file.
- If **Overwrite**: Continue to step 3.

### 3. Collect project details

**If the user provided details with the command** (the invocation text contains a project name and at least one directory with a label and a path): parse `project_name` (required), `description` (optional), `dirs` (a list of `{label, path}`, at least one), and `rules` (optional list of rule-file paths) from the text, and SKIP the interactive guided collection below. Do NOT ask the "AddDir" or "Rules" questions in this mode. **In arg mode, when `.ca/project.yaml` does not already exist, the FIRST `AskUserQuestion` you issue MUST be the step 4 `"Confirm"` question — never `"AddDir"` or `"Rules"`.**

**Otherwise (interactive guided collection)**:
1. Ask the user for the **project name**. Wait for their reply.
2. Ask for an optional **one-line description**. Allow them to skip.
3. Collect **directories** in a loop. For each directory:
   a. Ask for the directory **label** (a simple slug — letters, digits, hyphens, no colons — e.g. `code`, `paper`) and its **path** (absolute). Wait for their reply.
   b. `AskUserQuestion`: header MUST be exactly `"AddDir"`, question "Add another directory?", options "Add another" / "Done".
   c. If **Add another**: repeat from (a). If **Done**: exit the loop.
   Require at least one directory — if the user chose "Done" with zero directories, ask for one before continuing.
4. Collect optional **rules**. `AskUserQuestion`: header MUST be exactly `"Rules"`, question "Add project-wide rule files?", options "Add rules" / "Skip". If **Add rules**: ask the user for the **paths to rule files** (one absolute path per line). Each entry is a path to a file (e.g. a `CLAUDE.md`) whose contents `/ca:execute` will load as additional context for executor agents — NOT inline rule text. If **Skip**: no rules.

### 4. Present preview and confirm

Present the exact `.ca/project.yaml` content that will be written:

```yaml
project_name: <name>
description: <description>      # omit this line if no description
dirs:
  - label: <label1>
    path: <path1>
  - label: <label2>
    path: <path2>
rules:                          # omit this section entirely if no rules; each item is a path to a rule file
  - <path-to-rule-file>
```

`AskUserQuestion`:
- **CRITICAL**: header MUST be exactly `"Confirm"`.
- question: "Write this project.yaml?"
- options:
  - "Write" — "Write the file as shown"
  - "Edit" — "Change something first"
  - "Cancel" — "Don't write the file"
- If **Edit**: ask what to change, revise the preview, re-present, and re-ask this confirmation.
- If **Cancel**: Stop immediately. Do NOT write the file.
- If **Write**: Continue to step 5.

### 5. Write project.yaml

Write the confirmed content to `.ca/project.yaml`. The structure MUST be: `project_name:` (string), `description:` (string, only if provided), `dirs:` (a YAML list where each item has `label:` and `path:`), `rules:` (a YAML list of **file paths**, each a path to a rule file whose content `/ca:execute` reads — only if provided). Each `label` MUST be a simple slug (letters/digits/hyphens, no colons) so the `project_worktrees` `label:original_path:worktree_path` triples stay parseable. This structure is consumed by `ca-config.js` (which emits a `## Project` section with `project_dirs`/`project_rules`) and by `/ca:new`, `/ca:quick`, `/ca:instant` (5c) and `/ca:execute`.

### 6. Confirm completion

Tell the user `.ca/project.yaml` has been created and show its path. Mention that `/ca:new`, `/ca:quick`, and `/ca:instant` will now offer per-repo worktree creation for the registered directories. Suggest next step: `/ca:new` (or `/ca:quick` / `/ca:instant`).

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.
