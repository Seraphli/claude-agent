# /ca:execute — Execute Confirmed Plan

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `plan_confirmed: true`. If not, tell the user to run `/ca:plan` first and get all three confirmations. **Stop immediately.**

## Behavior

You are the execution orchestrator. You delegate the actual work to the `ca-executor` agent running in the foreground.

### 1. Read context

Read these files and collect their full content:
- `.ca/workflows/<active_id>/PLAN.md`
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick`)

Read `fix_round` from STATUS.md (default: 0).
If `fix_round` > 0 (fix round N):
- Read PLAN.md from `.ca/workflows/<active_id>/rounds/<N>/PLAN.md`

### 1b. Ensure codebase map exists

Check if `.ca/map.md` exists:
- If it does NOT exist, check if the project has existing source files (i.e., the project is not empty).
  - If the project is **not empty**: Run `/ca:map` to create the codebase map before proceeding to execution.
  - If the project is **empty** (new project): Skip for now — the map will be created after execution (see step 7).

### 2. Resolve model for ca-executor

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-executor_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `~/.claude/ca/references/model-profiles.md` and look up the model for `ca-executor` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Parse execution order

Parse the `## Implementation Steps` section in PLAN.md to determine execution order based on list structure:

- **Ordered list items** → execute sequentially (wait for previous to complete)
- **Unordered list items** → execute in parallel (launch simultaneously)
- **Nested lists** → follow the nesting structure recursively

For each executable item (leaf node in the list), find its corresponding entry in the `## Step Details` section. The detail content is what gets passed to the executor agent.

### 3a. Sequential execution

For ordered list items or single items: launch a single `ca-executor` agent with the step details inlined in the prompt. Wait for completion before proceeding to the next item.

### 3b. Parallel execution

For unordered list items: read `max_concurrency` from config (default: `4`). If the number of items exceeds `max_concurrency`, split into batches of `max_concurrency` size and execute batches sequentially. For each batch (or all items if within limit), launch multiple `ca-executor` agents **in the same message** (one per item). Each agent receives:
- Its specific step details inlined in the prompt
- The full content of REQUIREMENT.md (or BRIEF.md)
- The project root path
- A unique output file path: `SUMMARY-executor-{N}.md`

Wait for all parallel agents to complete before proceeding to the next sequential item.

### 4. Write SUMMARY.md

- **Single executor mode (3a)**: Take the agent's returned summary and write it to `.ca/workflows/<active_id>/SUMMARY.md`.
- **Parallel execution mode (3b)**: Read all `SUMMARY-executor-*.md` files from `.ca/workflows/<active_id>/`, merge them into a single coherent summary, and write the merged result to `.ca/workflows/<active_id>/SUMMARY.md`. Then delete the individual `SUMMARY-executor-*.md` files.

If fix_round > 0, write to `.ca/workflows/<active_id>/rounds/<N>/SUMMARY.md`.

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

If `.ca/map.md` does not exist (e.g., new project that was empty before execution), create it now by running the equivalent of `/ca:map` — scan the project structure and write `.ca/map.md`.

### 8. Auto-proceed to verification

**First**, check if `batch_mode: true` is set in `.ca/workflows/<active_id>/STATUS.md`:
- If `batch_mode: true`, do NOT auto-proceed to verify regardless of `auto_proceed_to_verify` config. The batch orchestrator will call verify separately. Tell the user execution is complete and stop here.

**Otherwise**, check config for `auto_proceed_to_verify`:
- If `true`: Tell the user execution is complete, then automatically execute `Skill(ca:verify)`.
- If `false` or not set: Tell the user execution is complete. Suggest next steps:
  - Run `/ca:verify` to verify the results (or use `/ca:next`)
  - Suggest using `/clear` before proceeding to free up context
  - Also mention: "Tip: You can set `auto_proceed_to_verify: true` in `/ca:settings` to auto-proceed."

**Do NOT proceed to verification automatically, unless `auto_proceed_to_verify` is set to `true` in config and `batch_mode` is not enabled.**
