# /ca:remember — Save to Persistent Context

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/context.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

The user wants to save information to persistent context that will be available across workflow cycles.

### 1. Get the information

The user's message after `/ca:remember` contains the information to save. If empty, ask what they want to remember.

### 2. Append to context.md

Read `.dev/context.md`, then append the new information as a bullet point with a timestamp:

```markdown
- [YYYY-MM-DD] <information>
```

### 3. Confirm

Tell the user the information has been saved. Show the updated context.
