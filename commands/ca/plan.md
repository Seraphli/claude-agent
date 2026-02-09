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
- `.ca/map.md` (if exists — use as codebase reference for understanding project structure)
- `.ca/current/CRITERIA.md` (if exists — from previous cycle, for fix append mode)

### 1b. Research (quick workflow only)

If `workflow_type: quick`, perform automatic 4-dimension research before drafting the plan. This follows the same pattern as the discuss command's automated research:

1. Resolve model for ca-researcher (same logic as discuss).
2. Launch 4 parallel ca-researcher agents (Stack, Features, Architecture, Pitfalls) with BRIEF.md content, project root, and map.
3. Present merged research findings to the user.

If `workflow_type: standard`, skip this step (research was already done in discuss).

### 1c. Clarify uncertain items

Before proceeding to draft the plan, check if there are any uncertain or ambiguous items discovered during research (from discuss phase or step 1b). If there are:

1. List each uncertain item to the user.
2. Ask the user to clarify each one, one at a time.
3. Only proceed to drafting the plan after all uncertainties are resolved.

This ensures that the triple confirmation below contains only concrete, well-defined content — no items should say "needs further research" or "to be determined".

### 2. Draft the plan

Prepare a plan covering:
- **Approach**: What method/strategy will be used
- **Files to modify**: List each file and what changes
- **Files to create**: List any new files
- **Implementation steps**: Numbered, ordered steps
- **Expected results**: What the end state looks like

**Execution Order**: Implementation Steps use a multi-level list outline to express execution order:
- **Ordered list** (1. 2. 3.) = sequential execution, items have dependencies
- **Unordered list** (- - -) = parallel execution, items are independent

Nesting is supported. For example:
1. Preparation step
2. Parallel modifications:
   - Modify file A
   - Modify file B
   - Modify file C
3. Final integration step

When all steps are independent, use a single unordered list. When all steps are sequential, use a single ordered list. Only use mixed/nested lists when the execution order genuinely requires it — keep it simple.

After the outline, provide a "## Step Details" section with detailed instructions for each step. The outline determines execution order; Step Details provides the implementation content for each step.

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

**IMPORTANT**: This step ONLY confirms whether the requirement understanding is correct. Do NOT discuss approach, method, or implementation details here. Those belong in Confirmation 2.

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

- If **Disagree**: Ask what should change, revise the approach. Then check: does this change affect the requirement understanding confirmed in Confirmation 1? If yes, inform the user and re-ask Confirmation 1 first, then re-ask Confirmation 2. If no, re-ask Confirmation 2 only.

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

- If **No**: Ask what the expected results should be, revise. Then check: does this change affect the approach (Confirmation 2) or requirement understanding (Confirmation 1)? If yes, inform the user and re-ask the affected confirmations in order, then re-ask Confirmation 3. If no, re-ask Confirmation 3 only.

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

Write success criteria to `.ca/current/CRITERIA.md`:

If the file already exists (fix mode), append new criteria below the existing ones.
If the file does not exist, create it:

```
# Success Criteria

Each criterion must be tagged with `[auto]` (verifiable by automated checks — reading files, running tests, etc.) or `[manual]` (requires user confirmation).

Group criteria by type. Within each group, use unordered list if items are independent (can be verified in parallel), or ordered list if items have dependencies (must be verified sequentially).

**[auto]**

- criterion 1
- criterion 2

**[manual]**

- criterion 3
- criterion 4
```

### 5. Update STATUS.md

Set `plan_completed: true`, `plan_confirmed: true`, `current_step: plan`.

Tell the user the plan is confirmed and they can proceed with `/ca:execute` (or `/ca:next`). Suggest using `/clear` before proceeding to free up context.

**Do NOT proceed to execution automatically.**
