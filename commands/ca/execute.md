# /ca:execute — Execute Confirmed Plan

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Check `.ca/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Read `.ca/current/STATUS.md` and verify `plan_confirmed: true`. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

## Behavior

You are the execution orchestrator. You delegate the actual work to the `ca-executor` agent running in the foreground.

### 1. Read context

Read these files and collect their full content:
- `.ca/current/PLAN.md`
- `.ca/current/REQUIREMENT.md` (or `.ca/current/BRIEF.md` if `workflow_type: quick`)

### 2. Resolve model for ca-executor

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-executor_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `references/model-profiles.md` and look up the model for `ca-executor` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Launch ca-executor agent

Use the Task tool with `subagent_type: "ca-executor"` and the resolved `model` parameter to launch the ca-executor agent. Pass it:
- The full content of PLAN.md
- The full content of REQUIREMENT.md (or BRIEF.md if `workflow_type: quick`)
- The project root path
- Instructions to follow the `ca-executor` agent prompt

The agent runs in the foreground and executes the implementation steps, returning an execution summary.

### 4. Write SUMMARY.md

Take the agent's returned summary and write it to `.ca/current/SUMMARY.md`.

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

### 7. Update codebase map

If `.ca/map.md` exists:
- Read the current map and the execution summary
- Update `.ca/map.md` to reflect any new or modified files and their purposes
- Update the "Last updated" date

If `.ca/map.md` does not exist, skip this step. The user can run `/ca:map` to create it.

### 8. Auto-proceed to verification

Check config for `auto_proceed_to_verify`.
- If `true`: Tell the user execution is complete, then automatically execute `Skill(ca:verify)`.
- If `false` or not set: Tell the user execution is complete. Suggest using `/clear` before verification to free up context, then tell the user to run `/ca:verify`. Also mention: "Tip: You can set `auto_proceed_to_verify: true` in `/ca:settings` to auto-proceed."

**Do NOT proceed to verification automatically, unless `auto_proceed_to_verify` is set to `true` in config.**
