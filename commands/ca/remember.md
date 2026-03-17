---
name: ca-remember
description: Saves information to persistent context at project or global level. Use when user wants to persist information.
---

# /ca:remember — Save to Persistent Context

**CRITICAL — Code Modification Policy**: This command only writes to ca-context.md files. Do NOT modify source code.

## Prerequisites

No prerequisites — context files are created on demand.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

The user wants to save information to persistent context that will be available across workflow cycles.

### 1. Get the information

The user's message contains the information to save. If empty, ask what to remember. **Always preserve exact original wording.**

### 2. Ask target level

Use `AskUserQuestion` with:
- header: "Level"
- question: "Save to global or project context?"
- options:
  - "Project" — "Save to .claude/rules/ca:context.md (this project only)"
  - "Global" — "Save to ~/.claude/rules/ca:context.md (all projects)"

### 3. Append to context file

**IMPORTANT**: Preserve the user's exact input verbatim. Do NOT rephrase, summarize, or rewrite.

Based on the user's choice:
- **Project**: Read `.claude/rules/ca:context.md`, then append the new information as a bullet point with a timestamp:
  ```
  - [YYYY-MM-DD] <information>
  ```
- **Global**: Read `~/.claude/rules/ca:context.md` (create if it doesn't exist), then append in the same format.

### 4. Confirm

Tell the user the information has been saved and to which level. Show the updated context.
