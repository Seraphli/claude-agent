# /ca:discuss — Discuss Requirements

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If `.ca/active.md` does not exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, tell the user: "This is a quick workflow. The discuss step is skipped. Please proceed with `/ca:plan`." **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

Goal: understand **exactly** what the user wants before code is written.

### 1. Automated Research

Perform automatic research before the discussion.

#### 1a. Resolve model for ca-researcher

Resolve model: `ca-researcher_model` override → `model_profile` (default: `balanced`) via `~/.claude/ca/references/model-profiles.md`. Pass to Task tool.

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

Launch **4 parallel ca-researcher agents** (single message), each with resolved model. Pass each:
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

Read BRIEF.md as the starting point. Also read `.ca/map.md` (if exists) for project context. Incorporate any task description provided with this command. If no brief or description exists, ask what they want.

### 3. Ask clarifying questions ONE AT A TIME

Ask ONE question at a time (most important first). Focus on: Scope, Behavior, Constraints, Success criteria. Typically 2-5 questions suffice.

**IMPORTANT**: If the user indicates they don't understand your question, you MUST stop and explain or rephrase the current question. Do NOT move on to the next question until the current one is resolved. Follow the Discussion Completeness Rule in `_rules.md`.

Use `AskUserQuestion` for questions with clear options. Reserve plain text for open-ended questions.

**Supplementary Research**: Launch additional ca-researcher agents if the user raises questions needing investigation.

### 4. Present requirement summary

Present a structured summary:

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
Update STATUS.md (`discuss_completed: true`, `current_step: discuss`). Tell the user discussion is complete. Suggest next steps:
- `/ca:plan` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

- If **Needs changes**: Ask what needs to change, revise the summary, and ask for confirmation again.

**Do NOT auto-proceed.**
