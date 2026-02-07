# /ca:research — Analyze Codebase and Resources

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

Read and follow the rules defined in `commands/ca/_rules.md` (installed at `~/.claude/commands/ca/_rules.md`).

## Prerequisites

1. Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Check `.dev/current/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.
3. Read `.dev/current/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, tell the user: "This is a quick workflow. The research step is skipped. Please proceed with `/ca:plan`." **Stop immediately.**

## Behavior

You are the research orchestrator. Use the `ca-researcher` agent for deep codebase analysis.

### 1. Read context

Read these files:
- `.dev/current/REQUIREMENT.md`
- `.dev/context.md` (if it has content)
- `.dev/errors.md` (if exists — review past mistakes to avoid repeating them)
- `~/.claude/ca/errors.md` (if exists — review global error lessons)

### 2. Resolve model for ca-researcher

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-researcher_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `references/model-profiles.md` and look up the model for `ca-researcher` in the corresponding profile column.
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

### 6. MANDATORY CONFIRMATION

Use `AskUserQuestion` with:
- header: "Findings"
- question: "Are these findings accurate and complete?"
- options:
  - "Accurate" — "Findings look good, proceed"
  - "Needs changes" — "Something is missing or incorrect"

- If **Accurate**: Write the findings to `.dev/current/RESEARCH.md` and update STATUS.md (`research_completed: true`, `current_step: research`). Tell the user they can proceed with `/ca:plan`.
- If **Needs changes**: Ask what's missing or incorrect, do additional research, and ask for confirmation again.

**Do NOT proceed to any next step automatically.**
