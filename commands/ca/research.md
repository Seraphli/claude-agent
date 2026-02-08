# /ca:research — Analyze Codebase and Resources

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Check `.ca/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Check `.ca/current/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.
3. Read `.ca/current/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, tell the user: "This is a quick workflow. The research step is skipped. Please proceed with `/ca:plan`." **Stop immediately.**

## Behavior

You are the research orchestrator. Use the `ca-researcher` agent for deep codebase analysis.

### 1. Read context

Read these files:
- `.ca/current/REQUIREMENT.md`
- `.ca/map.md` (if exists — use as codebase reference for understanding project structure)

### 2. Resolve model for ca-researcher

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-researcher_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `~/.claude/ca/references/model-profiles.md` and look up the model for `ca-researcher` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Launch ca-researcher agent

Use the Task tool with `subagent_type: "ca-researcher"` and the resolved `model` parameter to launch the ca-researcher agent. Pass it:
- The full content of REQUIREMENT.md
- The project root path
- Instructions to follow the `ca-researcher` agent prompt

The agent will analyze the codebase and return structured findings.

### 4. Present findings to user

Display the research findings clearly:

```
## Research Findings

### Relevant Files
- file1.py — reason
- file2.py — reason

### Key Patterns
- ...

### Constraints/Dependencies
- ...

### External Resources (if any)
- ...
```

### 5. Ask about external research

Ask the user if they need any external resources searched (documentation, APIs, etc.). If yes, launch another research task.

### 6. Confirmation and next step

Check config for `auto_proceed_to_plan`:

- If `true`: Skip user confirmation. Write the findings to `.ca/current/RESEARCH.md` and update STATUS.md (`research_completed: true`, `current_step: research`). Tell the user research is complete and automatically execute `Skill(ca:plan)`.
- If `false` or not set: Use `AskUserQuestion` with:
  - header: "Findings"
  - question: "Are these findings accurate and complete?"
  - options:
    - "Accurate" — "Findings look good, proceed"
    - "Needs changes" — "Something is missing or incorrect"
  - If **Accurate**: Write the findings to `.ca/current/RESEARCH.md` and update STATUS.md (`research_completed: true`, `current_step: research`). Tell the user they can proceed with `/ca:plan` (or `/ca:next`). Also mention: "Tip: You can set `auto_proceed_to_plan: true` in `/ca:settings` to auto-proceed."
  - If **Needs changes**: Ask what's missing or incorrect, do additional research, and ask for confirmation again.
