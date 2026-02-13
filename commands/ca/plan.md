# /ca:plan — Propose Implementation Plan (Triple Confirmation)

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID (`<active_id>`). If the file doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and check `workflow_type`. If `workflow_type: quick`, skip the REQUIREMENT.md check. Otherwise, check `.ca/workflows/<active_id>/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.

## Behavior

This is the **most critical step** in the workflow. You must get **three separate confirmations** before the plan is finalized.

### 1. Read context

Read these files:
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick`)
- `.ca/map.md` (if exists — use as codebase reference for understanding project structure)
- `.ca/workflows/<active_id>/CRITERIA.md` (if exists — from previous cycle, for fix append mode)

### 1b. Research (quick workflow only)

If `workflow_type: standard`, skip this step (research was already done in discuss).

If `workflow_type: quick`:

1. **Analyze requirement complexity**: Read BRIEF.md content and assess whether the requirement is simple enough to skip research. A requirement is considered **simple** if it meets ALL of the following:
   - The scope is narrow and clearly defined (e.g., modifying 1-2 files)
   - No architectural changes involved
   - No new technologies, libraries, or dependencies
   - Examples: documentation updates, config adjustments, simple bug fixes, minor text changes, straightforward additions to existing patterns

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

3. **Execute 4-dimension research** (same pattern as discuss command):
   1. Resolve model for ca-researcher (same logic as discuss).
   2. Launch 4 parallel ca-researcher agents (Stack, Features, Architecture, Pitfalls) with BRIEF.md content, project root, and map.
   3. Present merged research findings to the user.

### 1c. Clarify uncertain items

**Note**: If research was skipped in step 1b, skip this step entirely and proceed to step 2.

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

**Fix Append Mode**: If `.ca/workflows/<active_id>/PLAN.md` already exists with "## Fix Notes" section:
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

Present the plan in TWO parts:

**Part 1 — Outline**: First present a concise outline (table-of-contents style) containing ONLY:
- Approach (1-2 sentences)
- Files to modify/create (bullet list)
- Implementation steps outline (multi-level ordered/unordered list, NO details — just step titles)

**Part 2 — Step Details**: Then present detailed instructions for each step in the outline, with exact code/text changes, file locations, and before/after examples.

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

Only after ALL THREE confirmations pass, write the complete plan to `.ca/workflows/<active_id>/PLAN.md`:

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

If the file already exists (fix mode), append new criteria below the existing ones.
If the file does not exist, create it:

```
# Success Criteria

Each criterion must be tagged with `[auto]` or `[manual]`:

**Use `[auto]` when the verifier can check it by:**
- Reading file contents (checking if code/config contains expected content)
- Running shell commands (tests, linters, build checks)
- Searching with grep/glob (verifying patterns exist or don't exist)
- Comparing file structures (checking files were created/modified)

**Use `[manual]` ONLY when verification genuinely requires:**
- User interaction with a UI/application (e.g., "click button and verify behavior")
- Subjective human judgment (e.g., "the error message is clear and helpful")
- Access to external services the verifier cannot reach (e.g., "verify the deployment works")
- Real-time observation (e.g., "watch the animation play smoothly")

**Default to `[auto]`** — if unsure whether a criterion can be automated, prefer `[auto]`. The verifier has Read, Bash, Grep, and Glob tools and can verify most code-level checks automatically.

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

**Batch tip**: If you have multiple requirements to implement, you can plan them all first (using `/ca:quick` or `/ca:new` for each), then use `/ca:batch` to execute all confirmed plans sequentially.

**Do NOT proceed to execution automatically.**
