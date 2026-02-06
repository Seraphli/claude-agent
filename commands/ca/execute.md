# /ca:execute — Execute Confirmed Plan

Read `.dev/config.md` to determine the user's preferred language. Respond in that language.

## Prerequisites

1. Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:init` first and stop.
2. Read `.dev/current/STATUS.md` and verify `plan_confirmed: true`. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

## Behavior

You are the execution orchestrator. You delegate the actual work to the `ca-executor` agent running in an independent context.

### 1. Read context

Read these files and collect their full content:
- `.dev/current/PLAN.md`
- `.dev/current/REQUIREMENT.md`
- `.dev/context.md` (if it has content)

### 2. Launch ca-executor agent

Use the Task tool with `subagent_type: "general-purpose"` to launch the ca-executor agent. Pass it:
- The full content of PLAN.md
- The full content of REQUIREMENT.md
- The full content of context.md (if any)
- The project root path
- Instructions to follow the `ca-executor` agent prompt

The agent executes the implementation steps and returns an execution summary.

### 3. Write SUMMARY.md

Take the agent's returned summary and write it to `.dev/current/SUMMARY.md`.

### 4. Present execution summary

Display to the user:

```
## Execution Summary

### Changes Made
- file1.py — what changed
- file2.py — what changed

### Steps Completed
1. ...
2. ...

### Notes/Deviations (if any)
- ...
```

### 5. Update STATUS.md

Set `execute_completed: true`, `current_step: execute`.

Tell the user execution is complete and they can proceed with `/ca:verify`.

**Do NOT proceed to verification automatically.**
