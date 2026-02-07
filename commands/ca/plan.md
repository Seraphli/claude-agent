# /ca:plan — Propose Implementation Plan (Triple Confirmation)

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Check `.ca/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Read `.ca/current/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, skip the REQUIREMENT.md check. Otherwise, check `.ca/current/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.

## Behavior

This is the **most critical step** in the workflow. You must get **three separate confirmations** before the plan is finalized.

### 1. Read context

Read these files:
- `.ca/current/REQUIREMENT.md` (or `.ca/current/BRIEF.md` if `workflow_type: quick`)
- `.ca/current/RESEARCH.md` (if exists)
- `.ca/map.md` (if exists — use as codebase reference for understanding project structure)
- `.ca/current/CRITERIA.md` (if exists — from previous cycle, for fix append mode)

### 2. Draft the plan

Prepare a plan covering:
- **Approach**: What method/strategy will be used
- **Files to modify**: List each file and what changes
- **Files to create**: List any new files
- **Implementation steps**: Numbered, ordered steps
- **Expected results**: What the end state looks like

**IMPORTANT — Plan Detail Requirement**: Each implementation step MUST contain the specific content to be added or modified. Include:
- The exact text/code to insert or change (use code blocks or quoted text)
- The precise location in the file (which section, after which line/paragraph)
- Before/after examples where applicable

The plan must be detailed enough that the executor agent can follow it mechanically without making independent design decisions.

**Fix Append Mode**: If `.ca/current/PLAN.md` already exists with "## Fix Notes" section:
- Read the existing PLAN.md
- Preserve all `[x]` marked (completed) steps as-is
- Update or replace `[ ]` marked steps as needed
- Append new fix steps at the end (before Success Criteria and Expected Results)
- Do NOT remove or rewrite completed steps
- Ensure the plan is coherent as a whole

### 3. TRIPLE CONFIRMATION (execute each in order, stop if any fails)

#### Confirmation 1: Requirement Understanding

Present: "Based on the requirements, I understand you want: [concise summary]"

Use `AskUserQuestion` with:
- header: "Requirements"
- question: "Is my understanding of the requirements correct?"
- options:
  - "Correct" — "Understanding is accurate"
  - "Not correct" — "Needs correction"

- If **Not correct**: Ask what you misunderstood, correct it, and re-ask Confirmation 1.

#### Confirmation 2: Approach and Method

Present the full approach, files to modify, and implementation steps.

Use `AskUserQuestion` with:
- header: "Approach"
- question: "Do you agree with this approach?"
- options:
  - "Agree" — "Approach looks good"
  - "Disagree" — "Needs adjustment"

- If **Disagree**: Ask what should change, revise the approach, and re-ask Confirmation 2.

#### Confirmation 3: Expected Results

Present the expected results and success criteria as **two separate sections**:

- **Expected Results**: What the end state looks like after implementation (observable changes, behavior)
- **Success Criteria**: Numbered, verifiable conditions to confirm correctness

Both are presented together for confirmation but clearly separated so the user can review each independently.

Use `AskUserQuestion` with:
- header: "Results"
- question: "Are these the expected results you want?"
- options:
  - "Yes" — "Expected results are correct"
  - "No" — "Needs revision"

- If **No**: Ask what the expected results should be, revise, and re-ask Confirmation 3.

### 3b. Self-check: Requirements Coverage

After all three confirmations pass, perform an automatic self-check before writing the plan:

1. Compare the confirmed success criteria against the original requirements (from REQUIREMENT.md or BRIEF.md).
2. For each requirement in the original document, verify there is at least one corresponding success criterion.
3. If any requirement is missing a corresponding criterion:
   - **Stop** and alert the user: "I found that the following requirements don't have corresponding success criteria: [list]"
   - Ask the user to confirm whether to add criteria for the missing items or intentionally exclude them.
   - Only proceed after the user confirms.
4. If all requirements are covered, proceed to write the plan.

### 4. Write PLAN.md

Only after ALL THREE confirmations pass, write the complete plan to `.ca/current/PLAN.md`:

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
1. ...
2. ...

## Expected Results
<confirmed expected results>
```

### 4b. Write/Update CRITERIA.md

Write success criteria to `.ca/current/CRITERIA.md`:

If the file already exists (fix mode), append new criteria below the existing ones.
If the file does not exist, create it:

```
# Success Criteria

1. ...
2. ...
```

### 5. Update STATUS.md

Set `plan_completed: true`, `plan_confirmed: true`, `current_step: plan`.

Tell the user the plan is confirmed and they can proceed with `/ca:execute` (or `/ca:next`). Suggest using `/clear` before proceeding to free up context.

**Do NOT proceed to execution automatically.**
