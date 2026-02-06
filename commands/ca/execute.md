# /ca:execute — Execute Confirmed Plan

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

1. Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Read `.dev/current/STATUS.md` and verify `plan_confirmed: true`. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

## Behavior

You are the execution orchestrator. You delegate the actual work to the `ca-executor` agent running in the foreground.

### 1. Read context

Read these files and collect their full content:
- `.dev/current/PLAN.md`
- `.dev/current/REQUIREMENT.md`
- `.dev/context.md` (if it has content)

### 2. Resolve model for ca-executor

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-executor_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `references/model-profiles.md` and look up the model for `ca-executor` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Launch ca-executor agent

Use the Task tool with `subagent_type: "ca-executor"` and the resolved `model` parameter to launch the ca-executor agent. Pass it:
- The full content of PLAN.md
- The full content of REQUIREMENT.md
- The full content of context.md (if any)
- The project root path
- Instructions to follow the `ca-executor` agent prompt

The agent runs in the foreground and executes the implementation steps, returning an execution summary.

### 4. Write SUMMARY.md

Take the agent's returned summary and write it to `.dev/current/SUMMARY.md`.

### 5. Present execution summary

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

### 6. Update STATUS.md

Set `execute_completed: true`, `current_step: execute`.

Tell the user execution is complete and they can proceed with `/ca:verify`.

**Do NOT proceed to verification automatically.**
