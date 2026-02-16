# /ca:discuss — Discuss Requirements

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If `.ca/active.md` does not exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, tell the user: "This is a quick workflow. The discuss step is skipped. Please proceed with `/ca:plan`." **Stop immediately.**

## Behavior

You are conducting a focused requirements discussion. Your goal is to understand **exactly** what the user wants before any code is written.

### 1. Automated Research

Before starting the discussion, perform an automatic 4-dimension research to gather context.

#### 1a. Resolve model for ca-researcher

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-researcher_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `~/.claude/ca/references/model-profiles.md` and look up the model for `ca-researcher` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

#### 1a-pre. Determine requirement type

Analyze BRIEF.md content to determine the requirement type:
- **New feature**: Adding functionality, enhancing, refactoring, documentation
- **Bug fix**: Fixing broken behavior, resolving errors, regressions

Look for keywords: "fix", "bug", "broken", "error", "regression" → bug fix; "add", "new", "implement", "enhance" → feature.

#### 1b. Launch researchers

**If new feature** (default): Launch 4 parallel ca-researcher agents as currently defined (Stack, Features, Architecture, Pitfalls).

**If bug fix**:
1. Parse bug descriptions from BRIEF.md. Identify each distinct bug/issue.
2. **Single bug**: Launch 1 ca-researcher with prompt: "Research the root cause of this bug: <description>. Examine relevant code, trace the issue, and report findings."
3. **Multiple bugs**: Launch multiple ca-researcher agents in parallel (one per bug, up to `max_concurrency`), each with a focused root-cause prompt.
4. Skip the 4-dimension agents.

Present findings under "## Research Findings" with bug-specific subsections.

**For new features**, use the Task tool to launch **4 ca-researcher agents in parallel** (in a single message), each with the resolved `model` parameter. Pass each agent:
- The full content of BRIEF.md
- The project root path
- The content of `.ca/map.md` (if exists)
- A specific research dimension:

**Agent 1 — Stack**: "Research the technology stack relevant to this requirement. Identify frameworks, libraries, dependencies, and technical constraints that apply."

**Agent 2 — Features**: "Research existing features and code related to this requirement. Find relevant files, functions, patterns, and current behavior."

**Agent 3 — Architecture**: "Research the architecture relevant to this requirement. Analyze module structure, data flow, integration points, and dependencies between components."

**Agent 4 — Pitfalls**: "Research potential risks and pitfalls for this requirement. Check error history (`.claude/rules/ca-errors.md`), known issues, and common mistakes in similar changes."

#### 1c. Present research findings

After all 4 agents complete, present a merged summary:

## Research Findings

### Stack
<findings from Agent 1>

### Features
<findings from Agent 2>

### Architecture
<findings from Agent 3>

### Pitfalls
<findings from Agent 4>

### 2. Start the discussion

Read `.ca/workflows/<active_id>/BRIEF.md` if it exists. Use the brief as the starting point for the discussion — acknowledge what the user wants to do based on the brief.

Also read `.ca/map.md` (if exists) to understand the project structure and inform the discussion.

If the user also provided a task description with this command, incorporate it as well.

If neither the brief nor a task description exists, ask what they want to accomplish.

### 3. Ask clarifying questions ONE AT A TIME

Do NOT dump a list of questions. Ask the most important question first, wait for the answer, then ask the next based on their response. Focus on:

- **Scope**: What exactly should change? What should NOT change?
- **Behavior**: What should happen? What's the expected input/output?
- **Constraints**: Any specific approaches to use or avoid?
- **Success criteria**: How will we know it's done correctly?

Keep asking until the requirements are clear. Typically 2-5 questions suffice.

**IMPORTANT**: If the user indicates they don't understand your question, you MUST stop and explain or rephrase the current question. Do NOT move on to the next question until the current one is resolved. Follow the Discussion Completeness Rule in `_rules.md`.

**When a question has clear, enumerable options** (e.g., choosing between approaches, selecting a strategy, yes/no decisions), use `AskUserQuestion` with appropriate options instead of plain text. Reserve plain text for open-ended questions that cannot be expressed as choices.

**Supplementary Research**: If during the discussion the user raises questions that require additional investigation, you can launch another ca-researcher agent with a targeted research prompt to gather the needed information. Present the findings to the user before continuing the discussion.

### 4. Present requirement summary

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
```

### 5. MANDATORY CONFIRMATION

Use `AskUserQuestion` with:
- header: "Requirements"
- question: "Does this accurately capture your requirements?"
- options:
  - "Accurate" — "Requirements are correct, proceed"
  - "Needs changes" — "I want to revise something"

- If **Accurate**: Write the summary to `.ca/workflows/<active_id>/REQUIREMENT.md` and also write the success criteria to `.ca/workflows/<active_id>/CRITERIA.md`:
```
# Success Criteria

1. ...
2. ...
```
Update STATUS.md (`discuss_completed: true`, `current_step: discuss`). Tell the user they can proceed with `/ca:plan` (or `/ca:next`). Suggest using `/clear` before proceeding to the next step to free up context.
- If **Needs changes**: Ask what needs to change, revise the summary, and ask for confirmation again.

**Do NOT proceed to any next step automatically. Wait for the user to invoke the next command.**
