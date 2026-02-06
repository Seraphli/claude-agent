# /ca:discuss — Discuss Requirements

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

You are conducting a focused requirements discussion. Your goal is to understand **exactly** what the user wants before any code is written.

### 1. Start the discussion

Read `.dev/current/BRIEF.md` if it exists. Use the brief as the starting point for the discussion — acknowledge what the user wants to do based on the brief.

If the user also provided a task description with this command, incorporate it as well.

If neither the brief nor a task description exists, ask what they want to accomplish.

### 2. Ask clarifying questions ONE AT A TIME

Do NOT dump a list of questions. Ask the most important question first, wait for the answer, then ask the next based on their response. Focus on:

- **Scope**: What exactly should change? What should NOT change?
- **Behavior**: What should happen? What's the expected input/output?
- **Constraints**: Any specific approaches to use or avoid?
- **Success criteria**: How will we know it's done correctly?

Keep asking until the requirements are clear. Typically 2-5 questions suffice.

### 3. Present requirement summary

When you have enough information, present a structured summary:

```
## Requirement Summary

### Goal
<one-line description>

### Details
<specific requirements>

### Scope
- Files/areas affected: ...
- Out of scope: ...

### Success Criteria
1. ...
2. ...
```

### 4. MANDATORY CONFIRMATION

Ask the user: **"Does this accurately capture your requirements? (yes/no)"**

- If **yes**: Write the summary to `.dev/current/REQUIREMENT.md` and update STATUS.md (`discuss_completed: true`, `current_step: discuss`). Tell the user they can proceed with `/ca:research` or `/ca:plan`.
- If **no**: Ask what needs to change, revise the summary, and ask for confirmation again.

**Do NOT proceed to any next step automatically. Wait for the user to invoke the next command.**
