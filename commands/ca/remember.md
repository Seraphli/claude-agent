# /ca:remember — Save to Persistent Context

## Prerequisites

No prerequisites — context files are created on demand.

## Behavior

The user wants to save information to persistent context that will be available across workflow cycles.

### 1. Get the information

The user's message after `/ca:remember` contains the information to save. If empty, ask what they want to remember. **Always preserve the user's exact original wording** — this is the user's own record, not your interpretation.

### 2. Ask target level

Use `AskUserQuestion` with:
- header: "Level"
- question: "Save to global or project context?"
- options:
  - "Project" — "Save to .claude/rules/ca-context.md (this project only)"
  - "Global" — "Save to ~/.claude/rules/ca-context.md (all projects)"

### 3. Append to context file

**IMPORTANT**: Always preserve the user's exact original input verbatim. Do NOT rephrase, summarize, abbreviate, or rewrite the user's words in any way. Record exactly what the user said, character by character.

Based on the user's choice:
- **Project**: Read `.claude/rules/ca-context.md`, then append the new information as a bullet point with a timestamp:
  ```
  - [YYYY-MM-DD] <information>
  ```
- **Global**: Read `~/.claude/rules/ca-context.md` (create if it doesn't exist), then append in the same format.

### 4. Confirm

Tell the user the information has been saved and to which level. Show the updated context.
