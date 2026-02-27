# /ca:plan — Propose Implementation Plan (Triple Confirmation)

Read config by running: `node ~/.claude/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ~/.claude/ca/scripts/ca-status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Check `workflow_type` from the parsed JSON. If `workflow_type: quick`, skip the REQUIREMENT.md check. Otherwise, check `.ca/workflows/<active_id>/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.

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
2. Resolve model for ca-researcher.
3. For each issue, launch a ca-researcher agent with:
   - The issue description, project root path, map content
   - Prompt: "Investigate the root cause of this issue: <issue>. Read relevant source code, trace the problem, report findings with file/line references."
4. Multiple independent issues → parallel researchers (up to `max_concurrency`).
5. Present findings to the user.
6. Skip step 1b, proceed to step 1c.

### 1b. Research (quick workflow only)

If fix_round > 0, skip this step (handled in 1a).

If `workflow_type: standard`, skip this step (research was already done in discuss).

If `workflow_type: quick`:

1. **Analyze requirement complexity**: Read BRIEF.md content and assess whether the requirement is simple enough to skip research. **Simple** = ALL of: narrow scope (≤2 files), no architectural changes, no new dependencies. Examples: doc updates, config changes, simple fixes.

2. **Based on complexity assessment**:
   - **If the requirement appears simple**: Use `AskUserQuestion` to ask the user:
     - header: "Research"
     - question: "This requirement appears simple enough to skip the 4-dimension research. Skip research and go straight to planning?"
     - options:
       - "Skip research" — "Go directly to planning"
       - "Run research" — "Execute 4-dimension research first"
     - If **Skip research**: Skip the rest of step 1b AND skip step 1c entirely. Proceed directly to step 2 (Draft the plan).
     - If **Run research**: Continue with step 3 below.
   - **If the requirement is complex**: Proceed directly with step 3 below (no need to ask).

3. **Determine requirement type and execute research**:
   1. **Analyze BRIEF.md content** to determine requirement type:
      - Look for keywords: "fix", "bug", "broken", "error", "regression" → **bug fix**
      - Look for keywords: "add", "new", "implement", "enhance" → **new feature**
   2. **Based on requirement type**:
      - **New feature**: Execute 4-dimension research (Stack, Features, Architecture, Pitfalls):
        1. Resolve model for ca-researcher (same logic as discuss).
        2. Launch 4 parallel ca-researcher agents with BRIEF.md content, project root, and map.
        3. Present merged research findings to the user.
      - **Bug fix**: Execute focused root-cause research:
        1. Parse bug descriptions from BRIEF.md.
        2. Resolve model for ca-researcher.
        3. Launch 1 ca-researcher agent per bug (up to max_concurrency) with prompt: "Investigate the root cause of this bug: <bug>. Read relevant source code, trace the problem, report findings with file/line references."
        4. Present findings to the user.

**IMPORTANT**: Research MUST prioritize `ca-researcher` agents (via the Task tool with subagent_type ca-researcher). Do NOT default to using Explore agents or general-purpose agents as a substitute for ca-researcher during this research phase.

### 1c. Clarify uncertain items

**Note**: If research was skipped in step 1b, skip this step entirely and proceed to step 2.

Check for uncertain items from research. If any:

1. List them to the user.
2. Clarify each one at a time.
3. Proceed only after all resolved — no "needs further research" or "TBD" in the plan.

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

**IMPORTANT**: Only confirm requirement understanding here. No approach/implementation details — those belong in Confirmation 2.

Present: "I understand you want: [concise summary]"

`AskUserQuestion`: header "Requirements", question "Is my understanding correct?", options "Correct"/"Not correct".

If **Not correct**: ask what's wrong, correct, re-ask.

#### Confirmation 2: Approach and Method

Present the plan in TWO parts:

**Part 1 — Outline** (3 sections):

1. **Approach**: 1-2 sentences (prose, not list)
2. **Files**: Bullet list of files to modify/create
3. **Implementation Steps**: Pure list outline — short titles only, no descriptions/prose. Ordered = sequential, unordered = parallel.

**Part 2 — Step Details**: Detailed instructions per step with exact changes, locations, before/after.

`AskUserQuestion`: header "Approach", question "Do you agree with this approach?", options "Agree"/"Disagree".

If **Disagree**: ask what to change, revise. If change affects Confirmation 1, re-ask it first, then re-ask Confirmation 2.

#### Confirmation 3: Expected Results

Present **two separate sections**: Expected Results (observable end state) and Success Criteria (verifiable conditions).

`AskUserQuestion`: header "Results", question "Are these the expected results?", options "Yes"/"No".

If **No**: revise. If change affects Confirmation 2 or 1, re-ask affected confirmations in order first.

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

Tell the user the plan is confirmed. Suggest next steps:
- `/ca:execute` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Batch tip**: Plan multiple requirements first (`/ca:quick`/`/ca:new`), then `/ca:batch` to execute all.

**Do NOT auto-proceed.**
