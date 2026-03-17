---
name: ca-plan
description: Proposes an implementation plan with triple confirmation. Use when a discussed requirement is ready for planning.
disable-model-invocation: true
---

# /ca-plan — Propose Implementation Plan (Triple Confirmation)

**CRITICAL — Code Modification Policy**: This command is for planning ONLY. Do NOT modify any source code or project files, regardless of whether this is a normal flow or fix round.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca-new` first and stop.
2. Check `workflow_type` from the parsed JSON. If `workflow_type: quick`, skip the REQUIREMENT.md check. Otherwise, check `.ca/workflows/<active_id>/REQUIREMENT.md` exists. If not, tell the user to run `/ca-discuss` first and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

Get **three separate confirmations** before finalizing.

### 1. Read context

Read these files:
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick`)
- `.ca/map.md` (if exists — use as codebase reference for understanding project structure)
- `.ca/workflows/<active_id>/CRITERIA.md` (if exists — from previous cycle, for fix append mode)

Also read `fix_round` from STATUS.md (default: 0).
If `fix_round` > 0 (fix round N):
- Read `.ca/workflows/<active_id>/rounds/<N>/ISSUES.md`
- This is a fix planning session

### 1a. Fix round research (fix mode only)

If `fix_round` == 0, skip this step.

If `fix_round` > 0 (fix round N):
1. Parse issues from `rounds/<N>/ISSUES.md`.
2. Read `ca-researcher_model` from the config JSON already loaded. This is the resolved model name (opus/sonnet/haiku).
3. Present the issues to the user and propose research directions for each.
4. Use `AskUserQuestion`:
   - header: "Research"
   - question: "Research these issues before planning the fix?"
   - options:
     - "Run all" — "Research all issues"
     - "Skip research" — "Go straight to planning"
5. **If Run all**: For each issue, launch a ca-researcher agent. Pass the resolved `ca-researcher_model` from the config JSON to each agent. Each agent receives:
   - The issue description, project root path, map content
   - Prompt: "Investigate the root cause of this issue: <issue>. Read relevant source code, trace the problem, report findings with file/line references."
   - Multiple independent issues → parallel researchers (up to `max_concurrency`).
6. **If Skip research**: Skip to step 1c.
7. Present findings to the user.
8. Skip step 1b, proceed to step 1c.

### 1b. Research (quick workflow only)

If fix_round > 0, skip this step (handled in 1a).

If `workflow_type: standard`, skip this step (research was already done in discuss).

If `workflow_type: quick`:

#### 1b-i. Assess requirement and approach

Read BRIEF.md and `.ca/map.md` (if exists). Assess:

1. **Requirement clarity**: Is it clear enough to determine research directions?
2. **Approach confidence**: Do you already have a rough idea of how to implement this?

**If requirement is vague**: Ask 1-3 focused preliminary questions to clarify scope before proposing research directions.

#### 1b-ii. Research confirmation

Based on your understanding, propose research directions:

**For new features**: You MAY use the 4 standard dimensions (Stack, Features, Architecture, Pitfalls) as a starting template, or generate task-specific directions, or a mix of both.

**For all other types**: Generate 2-4 task-specific research directions based on what you need to learn for this specific requirement. No fixed templates.

Present directions to the user with context:
- If approach is already clear: mention this, suggest research may not be essential but could help confirm.
- If uncertain: explain what you need to learn and why.

Use `AskUserQuestion`:
- header: "Research"
- question: "Here are the research directions I'd suggest. How would you like to proceed?"
- options:
  - "Run all (<N>)" — "Research all <N> proposed directions"
  - "Select directions" — "Choose which directions to research"
  - "Skip research" — "Go straight to planning"

**If Run all**: Proceed to launch all.
**If Skip research**: Skip rest of 1b AND 1c. Go to step 2 (Draft the plan).
**If Select directions**: `AskUserQuestion` with `multiSelect: true`, header "Directions", question "Select which directions to research:", options = proposed directions. If none selected, treat as skip.

#### 1b-iii. Launch and present

Read `ca-researcher_model` from the config JSON already loaded. Launch agents only for confirmed directions, each with BRIEF.md content, project root, map, and direction-specific prompt. Pass the resolved model to each agent. Launch in parallel (up to `max_concurrency`). Present findings to user.

**IMPORTANT**: Research MUST prioritize `ca-researcher` agents (via the Task tool with subagent_type ca-researcher). Do NOT default to using Explore agents or general-purpose agents as a substitute for ca-researcher during this research phase.

### 1c. Clarify uncertain items

**Note**: If research was skipped in step 1b, skip this step entirely and proceed to step 2.

Check for uncertain items from research. If any:

1. List them to the user.
2. Clarify each one at a time.
3. Proceed only after all resolved — no "needs further research" or "TBD" in the plan.

**CRITICAL — Pre-plan Requirement**: Before entering the triple confirmation flow, you MUST have already:
1. Completed ALL research (steps 1a/1b)
2. Read ALL relevant source files referenced in REQUIREMENT.md/BRIEF.md
3. Prepared the COMPLETE detailed plan internally (including exact code changes)

Confirmation 2a and 2b are presentations of an ALREADY-COMPLETED plan. Do NOT defer file reading or plan design to after Confirmation 2a.

### 2. Draft the plan

Prepare a plan covering:
- **Approach**: What method/strategy will be used
- **Files to modify**: List each file and what changes
- **Files to create**: List any new files
- **Implementation steps**: Numbered, ordered steps
- **Expected results**: What the end state looks like

**Execution Order**: ordered list = sequential, unordered list = parallel. Nesting supported:
1. Preparation step
2. Parallel modifications:
   - Modify file A
   - Modify file B
   - Modify file C
3. Final integration step

Use the simplest structure that matches actual dependencies.

After the outline, provide `## Step Details` with implementation content for each step.

**IMPORTANT — Plan Detail Requirement**: Each step MUST include:
- Exact text/code to add or change (code blocks or quoted text)
- Precise location (section, line/paragraph)
- Before/after examples where applicable

The executor must be able to follow mechanically without design decisions.

**Fix mode**: If `fix_round` > 0, the plan addresses issues from `rounds/<N>/ISSUES.md` and research findings from step 1a. Same plan structure, focused on fixing identified issues.

### 3. TRIPLE CONFIRMATION (execute each in order, stop if any fails)

#### Confirmation 1: Requirement Understanding

**IMPORTANT**: Only confirm requirement understanding here. No approach/implementation details — those belong in Confirmation 2a/2b.

Present: "I understand you want: [concise summary]"

`AskUserQuestion`: header "Requirements", question "Is my understanding correct?", options "Correct"/"Not correct".

If **Not correct**: ask what's wrong, correct, re-ask.

#### Confirmation 2a: Rough Plan

**CRITICAL — Flow Order**: The rough plan is a CODE-FREE summary of the detailed plan you have ALREADY prepared internally. You must have read all files and designed the full solution before presenting this. Do NOT present a rough plan first and then start reading files.

Present a rough plan with 3 sections:

1. **Approach**: 1-2 sentences describing the overall strategy (prose, not list)
2. **Files**: Bullet list of files to modify/create. For each file, describe the SPECIFIC changes in natural language (what will be added/removed/changed and where). Do NOT just restate requirements — describe the actual implementation changes. Do NOT include code blocks.
   - Example good: "`ca-config.js` — 在 resolved 对象构建后增加模型解析逻辑：内嵌 profile 表，遍历三个 agent 检查 override，无 override 则从 profile 查默认值填入"
   - Example bad: "`ca-config.js` — 添加模型解析功能"
3. **Expected Effect**: What the end result looks like — describe the observable behavior or output after implementation

**CRITICAL**: The `header` parameter MUST be exactly `"Rough Plan"`. Do NOT use alternative headers like "Approach", "Plan Overview", etc.

`AskUserQuestion`: header "Rough Plan", question "Is this rough plan feasible?", options "Feasible"/"Not feasible".

If **Not feasible**: ask what to change, revise. If change affects Confirmation 1, re-ask it first, then re-ask Confirmation 2a.

#### Confirmation 2b: Detailed Plan

Only generate detailed plan AFTER Confirmation 2a passes.

Present:

1. **Implementation Steps**: Pure list outline — short titles only, no descriptions/prose. Ordered = sequential, unordered = parallel.
2. **Step Details**: Detailed instructions per step with exact changes, locations, before/after.

**CRITICAL**: The `header` parameter MUST be exactly `"Detailed Plan"`. Do NOT use alternative headers like "Implementation", "Plan Details", etc.

`AskUserQuestion`: header "Detailed Plan", question "Do you agree with this detailed plan?", options "Agree"/"Disagree".

If **Disagree**: ask what to change, revise. If change affects Confirmation 2a or 1, re-ask affected confirmations in order first.

#### Confirmation 3: Expected Results

Present **two separate sections**: Expected Results (observable end state) and Success Criteria (verifiable conditions).

`AskUserQuestion`: header "Results", question "Are these the expected results?", options "Yes"/"No".

If **No**: revise. If change affects Confirmation 2b, 2a, or 1, re-ask affected confirmations in order first.

### 3b. Self-check: Requirements Coverage

Self-check after all confirmations: for EACH original requirement, verify at least one criterion covers it. Direction: requirement → criterion (NOT reverse).

If any lacks coverage: **stop**, alert user, ask whether to add or exclude. Proceed only after confirmation.

### 4. Write PLAN.md

Only after ALL THREE confirmations pass, write the complete plan to `.ca/workflows/<active_id>/PLAN.md`. If fix_round > 0, write to `.ca/workflows/<active_id>/rounds/<N>/PLAN.md`.

```markdown
# Implementation Plan

## Requirement Summary
<from REQUIREMENT.md, or from BRIEF.md if quick workflow>

## Approach
<confirmed approach>

## Files to Modify
- ...

## Files to Create
- ...

## Implementation Steps
<multi-level ordered/unordered list outline>

## Step Details
### Step 1: <title>
<detailed instructions>

### Step 2a: <title>
<detailed instructions>
...

## Expected Results
<confirmed expected results>
```

### 4b. Write/Update CRITERIA.md

Write success criteria to `.ca/workflows/<active_id>/CRITERIA.md`:

If file exists and fix_round > 0, append new fix-specific criteria below existing ones.
If the file does not exist, create it:

```
# Success Criteria

Tag each criterion `[auto]` or `[manual]`:

**`[auto]`**: verifier checks by reading files, running commands, grep/glob, comparing structures.
**`[manual]`**: requires UI interaction, subjective judgment, external services, or real-time observation.

**Default to `[auto]`** — verifier has Read, Bash, Grep, Glob. Group by type; unordered = parallel, ordered = sequential.

**[auto]**

- criterion 1
- criterion 2

**[manual]**

- criterion 3
- criterion 4
```

### 5. Update STATUS.md

Set `plan_completed: true`, `plan_confirmed: true`, `current_step: plan`.
Also set `status_note` to a context-aware summary, e.g.: "Plan confirmed. Ready for execution." (fix mode: "Fix round N plan confirmed. Ready for execution.")

Tell the user the plan is confirmed. Suggest next steps:
- `/ca-execute` (or `/ca-next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Batch tip**: Plan multiple requirements first (`/ca-quick`/`/ca-new`), then `/ca-batch` to execute all.

**Do NOT auto-proceed.**
