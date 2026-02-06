# /ca:plan — Propose Implementation Plan (Triple Confirmation)

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

1. Check `.dev/current/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
2. Read `.dev/current/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, skip the REQUIREMENT.md check. Otherwise, check `.dev/current/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.

## Behavior

This is the **most critical step** in the workflow. You must get **three separate confirmations** before the plan is finalized.

### 1. Read context

Read these files:
- `.dev/current/REQUIREMENT.md` (or `.dev/current/BRIEF.md` if `workflow_type: quick`)
- `.dev/current/RESEARCH.md` (if exists)
- `.dev/context.md` (if it has content)

### 2. Draft the plan

Prepare a plan covering:
- **Approach**: What method/strategy will be used
- **Files to modify**: List each file and what changes
- **Files to create**: List any new files
- **Implementation steps**: Numbered, ordered steps
- **Expected results**: What the end state looks like
- **Success criteria**: How to verify it works (from REQUIREMENT.md, or from BRIEF.md if quick workflow)

### 3. TRIPLE CONFIRMATION (execute each in order, stop if any fails)

#### Confirmation 1: Requirement Understanding

Present: "Based on the requirements, I understand you want: [concise summary]"

Ask: **"Is my understanding of the requirements correct? (yes/no)"**

- If **no**: Ask what you misunderstood, correct it, and re-ask Confirmation 1.

#### Confirmation 2: Approach and Method

Present the full approach, files to modify, and implementation steps.

Ask: **"Do you agree with this approach? (yes/no)"**

- If **no**: Ask what should change, revise the approach, and re-ask Confirmation 2.

#### Confirmation 3: Expected Results

Present the expected outcome and success criteria.

Ask: **"Are these the expected results you want? (yes/no)"**

- If **no**: Ask what the expected results should be, revise, and re-ask Confirmation 3.

### 4. Write PLAN.md

Only after ALL THREE confirmations pass, write the complete plan to `.dev/current/PLAN.md`:

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

## Success Criteria
1. ...
2. ...
```

### 5. Update STATUS.md

Set `plan_completed: true`, `plan_confirmed: true`, `current_step: plan`.

Tell the user the plan is confirmed and they can proceed with `/ca:execute`.

**Do NOT proceed to execution automatically.**
