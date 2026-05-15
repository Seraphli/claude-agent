---
name: ca-plan
description: Proposes an implementation plan. Triple confirmation for standard/quick/write workflows; single confirmation for instant workflows.
---

# /ca:plan — Propose Implementation Plan

**CRITICAL — Code Modification Policy**: This command is for planning ONLY. Do NOT modify any source code or project files, regardless of whether this is a normal flow or fix round.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

### Resolve workflow ID

Determine which workflow to operate on using this priority:

1. **Context inference**: If the current conversation has already been working with a specific workflow (e.g., you just ran `/ca:quick` or `/ca:plan` for it earlier in this session), use that workflow ID.
2. **Single workflow**: Run `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. If exactly one workflow exists, use it automatically.
3. **Multiple workflows**: If multiple workflows exist, present them to the user and ask which one to operate on:
   - `AskUserQuestion`: header "Workflow", question "Which workflow do you want to plan?", options: list each workflow (label: workflow ID, description: "<workflow_type>, step: <current_step>")
4. **No workflows**: If no workflows exist, tell the user to run `/ca:new` or `/ca:quick` first and stop.

After resolving `<active_id>`:

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root> --workflow-id <active_id>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Check `workflow_type` from the parsed JSON. If `workflow_type: quick` or `workflow_type: instant`, skip the REQUIREMENT.md check. Otherwise, check `.ca/workflows/<active_id>/REQUIREMENT.md` exists. If not, tell the user to run `/ca:discuss` first and stop.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

Get **three separate confirmations** before finalizing (for standard/quick/write workflows). For `workflow_type: instant`, use single confirmation — see section 3-instant.

### 0. Task cleanup and initialization

1. Call `TaskList` to get all existing tasks.
2. If no tasks exist, skip to step 5.
3. If ALL tasks are `completed`: call `TaskUpdate` with `status: "deleted"` for each task.
4. If any task is NOT `completed` (pending or in_progress):
   a. Call `TaskGet` for each uncompleted task.
   b. Analyze possible causes by cross-referencing with STATUS.md (e.g., session interrupted, phase skipped, abnormal exit).
   c. Present to user: list each uncompleted task with subject, status, and possible cause.
   d. `AskUserQuestion`: header "Tasks", question "There are uncompleted tasks from the previous phase. How to proceed?", options:
      - "Clear and continue" — "Delete all old tasks and start current phase"
      - "Stop" — "Pause to investigate the previous phase's issues"
   e. If "Clear and continue": call `TaskUpdate` with `status: "deleted"` for ALL tasks.
   f. If "Stop": stop current command immediately.
5. Create initial tasks based on workflow mode (mutually exclusive — pick ONE branch):

   **If `auto_fix_mode: true`** (auto-fix round — see step 1-auto, applies to ALL workflow types including instant):
   - `TaskCreate`: subject "Auto-fix: generate plan", activeForm "Generating fix plan"
   - `TaskCreate`: subject "Write PLAN.md", activeForm "Writing plan"

   **Else if `workflow_type: instant`** (single confirmation — see step 3-instant):
   - `TaskCreate`: subject "Read context & research", activeForm "Reading context"
   - `TaskCreate`: subject "Draft & confirm plan", activeForm "Drafting plan"
   - `TaskCreate`: subject "Write PLAN.md & CRITERIA.md", activeForm "Writing plan files"

   **Else** (default triple confirmation for quick/standard/write):
   - `TaskCreate`: subject "Read context & research", activeForm "Reading context"
   - `TaskCreate`: subject "Confirmation 1: Requirements", activeForm "Confirming requirements"
   - `TaskCreate`: subject "Create/Read SPEC", activeForm "Handling SPEC"
   - `TaskCreate`: subject "Draft plan", activeForm "Drafting plan"
   - `TaskCreate`: subject "Confirmation 2a: Rough Plan", activeForm "Confirming rough plan"
   - `TaskCreate`: subject "Confirmation 3: Expected Results", activeForm "Confirming results"
   - `TaskCreate`: subject "Write PLAN.md & CRITERIA.md", activeForm "Writing plan files"

   Note: "Confirm Step N" tasks for Confirmation 2b are created dynamically after 2a passes.

Mark the first task as `in_progress` ("Read context & research" or "Auto-fix: generate plan").

### 1. Read context

Read these files:
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick` or `workflow_type: instant`)
- `.ca/map.md` (if exists — use as codebase reference for understanding project structure)
- `.ca/workflows/<active_id>/SPEC.md` (read only when `workflow_type` is NOT `instant`. Instant workflows do not use SPEC.)
- `.ca/workflows/<active_id>/CRITERIA.md` (if exists — from previous cycle, for fix append mode)

Also read `fix_round` from STATUS.md (default: 0).
If `fix_round` > 0 (fix round N):
- Read `.ca/workflows/<active_id>/rounds/<N>/ISSUES.md`
- This is a fix planning session

### 1-auto. Auto-fix mode

Read `auto_fix_mode` from STATUS.md. If `auto_fix_mode: true`:

1. This is an automated fix round. Skip ALL research (steps 1a/1b), clarification (step 1c), and triple confirmation (step 3).
2. Read `rounds/<fix_round>/ISSUES.md` to understand what failed.
3. Read the previous plan and summary:
   - If fix_round == 1: read `PLAN.md` and `SUMMARY.md` from workflow root.
   - If fix_round > 1: read `rounds/<fix_round-1>/PLAN.md` and `rounds/<fix_round-1>/SUMMARY.md`.
4. Read ALL source files referenced in the issues to understand the current code state.
   **CRITICAL — Log-First Analysis**: Before analyzing code to draw conclusions:
   1. Search for available logs: VERIFY-REPORT.md, test output files, /tmp/*.log, command output files
   2. If logs exist, read and analyze them first — logs provide ground truth of actual runtime behavior
   3. Cross-reference log evidence with code to identify root cause
   4. Only if no logs exist, fall back to pure code analysis
   Do NOT skip log analysis and jump to code-only conclusions.
5. Generate a focused fix plan targeting ONLY the specific implementation bugs identified in ISSUES.md. The fix MUST be minimal — only change what is needed to fix the failing criteria. Do NOT redesign or restructure the approach.

Mark "Auto-fix: generate plan" as `completed`. Mark "Write PLAN.md" as `in_progress`.

6. Write the plan to `.ca/workflows/<active_id>/rounds/<fix_round>/PLAN.md` (same format as normal PLAN.md).

Mark "Write PLAN.md" as `completed`.

7. Keep existing CRITERIA.md unchanged (same criteria need to pass).
8. Update STATUS.md: run `node ... ca-status.js update --project-root <project-root> --workflow-id <active_id> plan_completed=true plan_confirmed=true current_step=plan "status_note=Auto-fix round <fix_round> plan generated. Auto-proceeding to execution."`
9. **Auto-proceed**: Call `Skill(ca:execute)`.

**Do NOT proceed to steps 1a, 1b, 1c, or 3 when auto_fix_mode is true.**

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
   - Prompt: "Investigate the root cause of this issue: <issue>. PRIORITY: First search for and analyze any available logs (test output, error logs, VERIFY-REPORT.md, /tmp/*.log, command output files). Understand actual runtime behavior from logs before reading code. Only fall back to pure code analysis if no logs exist. Then read relevant source code, trace the problem. Report findings with file/line references and log evidence."
   - Multiple independent issues → parallel researchers (up to `max_concurrency`).
6. **If Skip research**: Skip to step 1c.
7. Present findings to the user.
8. Skip step 1b, proceed to step 1c.

### 1b. Research (quick workflow only)

If fix_round > 0, skip this step (handled in 1a).

If `workflow_type: standard`, skip this step (research was already done in discuss).

If `workflow_type: quick` or `workflow_type: instant`:

#### 1b-i. Assess requirement and approach

Read BRIEF.md and `.ca/map.md` (if exists). Assess:

1. **Requirement clarity**: Is it clear enough to determine research directions?
2. **Approach confidence**: Do you already have a rough idea of how to implement this?

**If requirement is vague**: Ask 1-3 focused preliminary questions to clarify scope before proposing research directions.

#### 1b-ii. Research confirmation

Based on your understanding, scan the requirement against the 6 quick dimensions and propose research directions from dimensions that are Partial or Missing:

**Quick workflow — 6 dimensions:**

| # | Dimension | Focus |
|---|-----------|-------|
| 1 | Functional Scope & Behavior | What exactly should happen? |
| 2 | Edge Cases & Error Handling | Boundary conditions, failure modes |
| 3 | Constraints & Tradeoffs | Technical limits, backward compatibility |
| 4 | Integration & Dependencies | External systems, file dependencies |
| 5 | Completion Signals | How to verify "done"? |
| 6 | Terminology & Consistency | Naming conventions, style consistency |

For each dimension, assess Clear / Partial / Missing. Propose research directions only for Partial/Missing dimensions.

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
**If Skip research**: Mark "Read context & research" as `completed`. Skip rest of 1b AND 1c. Go to step 3 (Confirmation & Planning).
**If Select directions**: `AskUserQuestion` with `multiSelect: true`, header "Directions", question "Select which directions to research:", options = proposed directions. If none selected, treat as skip.

#### 1b-iii. Launch and present

Read `ca-researcher_model` from the config JSON already loaded. Launch agents only for confirmed directions, each with BRIEF.md content, project root, map, and direction-specific prompt. Pass the resolved model to each agent. Launch in parallel (up to `max_concurrency`). Present findings to user.

**CRITICAL — Log-First Analysis**: When investigating issues or understanding behavior, ALWAYS prioritize analyzing available logs before reading code. Search for: test output files, error logs, VERIFY-REPORT.md, /tmp/*.log, command output files. Logs provide ground truth of actual runtime behavior. Only fall back to pure code analysis if no logs exist. Do NOT skip log analysis and jump to code-only conclusions.

**IMPORTANT**: Research MUST prioritize `ca-researcher` agents (via the Task tool with subagent_type ca-researcher). Do NOT default to using Explore agents or general-purpose agents as a substitute for ca-researcher during this research phase.

### 1c. Clarify uncertain items

**Note**: If research was skipped in step 1b, skip this step entirely and proceed to step 3.

Check for uncertain items from research. If any:

1. List them to the user.
2. Clarify each one at a time.
3. Proceed only after all resolved — no "needs further research" or "TBD" in the plan.

Mark "Read context & research" as `completed`.

### 3-instant. Single Confirmation (instant workflow only)

If `workflow_type: instant`:

Skip the triple confirmation entirely (steps Confirmation 1, SPEC Handling, Confirmation 2a, 2b, Confirmation 3). Instead, use the following streamlined flow:

Mark "Draft & confirm plan" as `in_progress`.

#### Draft the plan

**CRITICAL — Complete Code Reading**: Before presenting the plan, you MUST:
1. Read ALL source files that will be modified or referenced
2. Design the COMPLETE solution with exact code changes, line numbers, and before/after examples

**CRITICAL — Log-First Analysis**: When analyzing code to understand current behavior or diagnose issues:
1. Search for available logs: VERIFY-REPORT.md, test output files, /tmp/*.log, command output files
2. If logs exist, read and analyze them first — logs provide ground truth of actual runtime behavior
3. Cross-reference log evidence with code to identify root cause
4. Only if no logs exist, fall back to pure code analysis
Do NOT skip log analysis and jump to code-only conclusions.

Prepare a plan covering:
- **Approach**: What method/strategy will be used
- **Files to modify/create**: List each file and what changes
- **Implementation steps**: Numbered, ordered steps with step details
- **Success criteria**: Verifiable conditions tagged `[auto]` or `[manual]`

**Execution Order**: ordered list = sequential, unordered list = parallel.

**IMPORTANT — Plan Detail Requirement**: Each step MUST include exact text/code to add or change, precise location, and before/after examples.

#### Present and confirm

Present the complete plan in a single output, then ask for confirmation:

`AskUserQuestion`: header "Plan", question "Confirm this plan?", options:
- "Confirm" — "Plan looks good, proceed to execution"
- "Not feasible" — "Needs changes"

If **Not feasible**: ask what to change, revise, re-present, re-confirm.
If **Confirm**: Mark "Draft & confirm plan" as `completed`. Proceed to step 4 (Write PLAN.md) and step 4b (Write CRITERIA.md).

**Fix round behavior**: When `fix_round` > 0 and `auto_fix_mode` is NOT set, the instant single confirmation applies. Read ISSUES.md and research findings, draft a focused fix plan, present for single confirmation (header "Plan"). No upgrade to triple confirmation. When `auto_fix_mode: true` is set (by verify.md when `auto_fix: true` config), the standard auto-fix zero-confirmation path (step 1-auto) takes over — auto_fix is an automatic repair mechanism that applies to all workflow types including instant.

### 3. TRIPLE CONFIRMATION (execute each in order, stop if any fails)

**CRITICAL — No Duplicate Questions**: Each AskUserQuestion in the triple confirmation MUST be asked exactly ONCE. After receiving the user's answer, proceed immediately to the NEXT confirmation step. Do NOT re-ask the same question or re-send the same AskUserQuestion header. The sequence is strictly: Requirements → Rough Plan → Detailed Plan → Results, each asked once.

#### Confirmation 1: Requirement Understanding

Mark "Confirmation 1: Requirements" as `in_progress`.

**IMPORTANT**: Only confirm requirement understanding here. No approach/implementation details — those belong in Confirmation 2a/2b.

Present: "I understand you want: [concise summary]"

`AskUserQuestion`: header "Requirements", question "Is my understanding correct?", options "Correct"/"Not correct".

If **Not correct**: ask what's wrong, correct, re-ask.

Mark "Confirmation 1: Requirements" as `completed`. Mark "Create/Read SPEC" as `in_progress`.

#### SPEC Handling

**If `workflow_type: quick` AND SPEC.md does NOT exist** (typical quick workflow path):

Based on the confirmed requirements (BRIEF.md) and any research findings from step 1b, draft a SPEC document with two sections:

**CRITICAL — SPEC Detail Requirements**: The SPEC MUST be detailed and specific. A SPEC that could be replaced by a single sentence summary is NOT acceptable. Follow these minimum requirements:

1. **Desired Result / User Experience**: For EACH feature or fix in the requirement:
   - **Trigger**: How does the user trigger this? (exact command, action, or condition)
   - **Interaction flow**: Step-by-step description of each interaction point, what the user does, and what the system responds with
   - **System response**: Exact outputs, prompts, file changes, or UI updates the user will see
   - **Edge cases**: Boundary conditions and error scenarios — what happens when input is missing, invalid, or conflicts arise
   - **Before/after comparison** (for fixes): What behavior exists now vs. what it will be after the fix

   **FORBIDDEN** (too vague):
   > "Users can create parallel workflows without interference."

   **CORRECT** (specific and actionable):
   > "When user runs `/ca:quick` while another workflow exists, the command scans `.ca/workflows/` to find unfinished workflows. If found, it shows an AskUserQuestion with Keep/Archive/Continue options. After creating the new workflow, no `active.md` is written. When user then runs `/ca:plan`, the command checks how many workflows exist: if exactly one, it auto-selects; if multiple, it presents an AskUserQuestion listing all workflows with their IDs, types, and current steps for user to choose."

2. **Verification Design**: Each test case MUST include:
   - **Precondition**: What state must exist before the test (files, config, prior actions)
   - **Action**: Exact operation to perform (command to run, input to provide)
   - **Assertion**: Specific expected result that can be verified (file content, command output, state change)

   **FORBIDDEN** (too vague):
   > "Verify that SPEC creation produces detailed output."

   **CORRECT** (specific and verifiable):
   > "Precondition: `plan.md` file exists in `commands/ca/`. Action: grep `plan.md` for 'CRITICAL.*SPEC Detail' and 'FORBIDDEN'. Assertion: Both patterns match, confirming the detail enforcement instructions are present."

Prioritize E2E/behavior-level tests that recreate the user's real usage path. Unit/integration tests may supplement but should not replace user-experience verification. Do NOT write complete bash scripts — describe actions and assertions clearly enough to be converted into E2E test phases later.

Present the draft SPEC to the user:

```
## SPEC Draft

### Desired Result / User Experience
<content>

### Verification Design
<test cases as action + assertion>
```

`AskUserQuestion`: header "SPEC", question "Does this SPEC accurately describe the desired result and verification design?", options "Accurate"/"Needs changes".

If **Needs changes**: ask what to change, revise, re-confirm.
If **Accurate**: Write to `.ca/workflows/<active_id>/SPEC.md`:

```markdown
# SPEC

## Desired Result / User Experience
<confirmed content>

## Verification Design
<confirmed content>
```

**If `workflow_type: standard` AND SPEC.md does NOT exist** (abnormal state — discuss should have created it):

Tell the user: "SPEC.md is missing. The discuss phase should have created it. Please run `/ca:discuss` to complete the requirement discussion and create SPEC.md."
**Stop immediately.**

**If SPEC.md exists** (normal standard workflow path, or quick workflow with pre-existing SPEC):

Read SPEC.md. Present a brief summary of its key points to the user (1-2 sentences covering desired result and verification approach). No confirmation needed — SPEC was already confirmed during discuss or a previous plan session. If the user identifies SPEC issues during the later Results confirmation (Confirmation 3), the SPEC revision path in Confirmation 3 handles it.

Mark "Create/Read SPEC" as `completed`. Mark "Draft plan" as `in_progress`.

**If `workflow_type: instant`** (no SPEC needed):

Instant workflows skip SPEC entirely. Do NOT create, read, or confirm SPEC.md. Proceed directly to the plan drafting step.

If a "Create/Read SPEC" task exists, mark it as `completed`. Mark "Draft & confirm plan" as `in_progress`.

#### Draft the plan

**CRITICAL — Complete Code Reading & Full Draft**: Requirements are now confirmed. Before presenting ANY plan to the user, you MUST:
1. Read ALL source files that will be modified or referenced in the plan
2. Design the COMPLETE solution with exact code changes, line numbers, and before/after examples
3. Produce a full internal draft that contains everything needed for Confirmation 2a (condensed) and 2b (detailed)

The draft plan is the COMPLETE, unconfirmed plan. Confirmation 2a presents it in condensed form, Confirmation 2b presents each step in full detail. Both are derived from this single draft — they are NOT separate design phases. The rough plan is a CONDENSED VERSION of the detailed plan, NOT a draft or sketch to be expanded.

**CRITICAL — SPEC-Driven Planning**: The plan MUST be driven by SPEC.md. Reference the Desired Result / User Experience section to understand what the end state should look like. Consider the test cases from Verification Design when designing implementation steps — the implementation should be structured so that each test case in the SPEC can verify the corresponding functionality.

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

Mark "Draft plan" as `completed`. Mark "Confirmation 2a: Rough Plan" as `in_progress`.

#### Confirmation 2a: Rough Plan

**CRITICAL — Flow Order**: The rough plan is a CODE-FREE CONDENSED VERSION of the draft plan completed above. It summarizes the SPECIFIC implementation changes (how to do it), NOT the requirements (what to do). Do NOT present a rough plan that merely restates requirements — it must describe concrete implementation changes for each file.

**Negative example** (FORBIDDEN — restating requirements):
> "`plan.md` — 强化 Pre-plan Requirement 指令"

**Positive example** (CORRECT — describing implementation):
> "`plan.md` — 将 Draft plan 步骤从 Confirmation 1 之前移到之后，新增 CRITICAL 段落要求先读完所有源文件再起草，并在 Flow Order 中增加反面/正面示例"

Present a rough plan with 3 sections:

1. **Approach**: 1-2 sentences describing the overall strategy (prose, not list)
2. **Files**: Bullet list of files to modify/create. For each file, describe the SPECIFIC changes in natural language (what will be added/removed/changed and where). Do NOT just restate requirements — describe the actual implementation changes. Do NOT include code blocks.
   - Example good: "`ca-config.js` — 在 resolved 对象构建后增加模型解析逻辑：内嵌 profile 表，遍历三个 agent 检查 override，无 override 则从 profile 查默认值填入"
   - Example bad: "`ca-config.js` — 添加模型解析功能"
3. **Expected Effect**: What the end result looks like — describe the observable behavior or output after implementation

**CRITICAL**: The `header` parameter MUST be exactly `"Rough Plan"`. Do NOT use alternative headers like "Approach", "Plan Overview", etc.

`AskUserQuestion`: header "Rough Plan", question "Is this rough plan feasible?", options "Feasible"/"Not feasible".

**CRITICAL — After-Answer Actions (MUST execute in order)**:

1. **If Not feasible**: ask what to change, revise. If change affects Confirmation 1, re-ask it first, then re-ask Confirmation 2a. Do NOT perform actions 2-3 until the user picks Feasible.
2. **If Feasible**: `TaskUpdate` "Confirmation 2a: Rough Plan" to `completed`. **This action is MANDATORY — skipping it will leave an orphan in_progress task and cause the next phase to fail with a "Tasks" cleanup prompt.**
3. After action 2 completes, proceed to Confirmation 2b below.

#### Confirmation 2b: Detailed Plan (Step-by-Step)

Only generate detailed plan AFTER Confirmation 2a passes.

**CRITICAL — Pre-2b Task Check (MANDATORY)**: Before creating any "Confirm Step N" task, you MUST call `TaskList` and verify that "Confirmation 2a: Rough Plan" has status `completed`. If it is still `in_progress` or `pending`, you forgot to mark it in the previous step — `TaskUpdate` it to `completed` immediately, then continue. Do NOT proceed to the step-by-step flow until 2a is verified as completed.

**Step-by-step confirmation flow:**

1. Present the **Implementation Steps** outline first (pure list, short titles only, ordered = sequential, unordered = parallel). This is the same outline format as before.

2. For EACH step in the outline, in order:
   a. `TaskCreate`: subject "Confirm Step N: <step title>", activeForm "Confirming step N".
   b. Mark the task as `in_progress`.
   c. Present that step's **Step Details** content (location, before/after, exact changes).
   d. `AskUserQuestion`: header "Step N", question "Does this step look correct?", options:
      - "Correct" — "This step is fine"
      - "Needs changes" — "I want to revise this step"
   e. If **Needs changes**: ask what to change, revise, re-present, re-confirm.
      If the change affects Confirmation 2a or 1, re-ask affected confirmations in order first (reset and re-create their tasks if needed).
   f. Mark "Confirm Step N" as `completed`.
   g. Proceed to the next step.

3. After ALL steps are confirmed, present a final summary: "All N steps confirmed."

**CRITICAL — No Conditional Descriptions in Step Details**: Every step MUST contain definitive instructions based on code you have ALREADY read. The following patterns are FORBIDDEN in Step Details:

- "Check if X exists, if so do A, otherwise do B"
- "If the code already has X, skip this step"
- "Verify whether X is present, then..."
- "Depending on the current state of..."
- "May need to..." / "Might require..."

These patterns mean the Pre-plan Requirement was not fulfilled — you have NOT read the actual code.

**Negative example** (FORBIDDEN):
> Check if `finish.md` has a gitignore section. If it does, add the filter before the existing check. If not, create the section from scratch.

**Positive example** (CORRECT):
> In `finish.md`, before line 36 (`Read .gitignore (create if needed)`), insert the following pre-check block: [exact content here]

**Self-check — Mechanical Executability**: After writing all Step Details, review each step: "Can the executor follow this mechanically without reading additional code or making any judgment?" If any step requires the executor to investigate, decide, or check conditions, rewrite that step with definitive instructions before presenting to the user.

#### Confirmation 3: Expected Results

Mark "Confirmation 3: Expected Results" as `in_progress`.

Present **two separate sections**:

1. **Expected Results**: Reference SPEC.md's Desired Result / User Experience — summarize the observable end state that the implementation plan will achieve.
2. **Success Criteria**: Derive verifiable criteria from SPEC.md's Verification Design. Tag each criterion as `[auto]` or `[manual]`:
   - **`[auto]`**: verifier checks by reading files, running commands, grep/glob, comparing structures.
   - **`[manual]`**: requires UI interaction, subjective judgment, external services, or real-time observation.
   - **Default to `[auto]`** — verifier has Read, Bash, Grep, Glob.

`AskUserQuestion`: header "Results", question "Are these the expected results?", options "Yes"/"No".

If **No**: ask what is wrong. If the feedback affects SPEC.md content (Desired Result or Verification Design), revise SPEC.md through the SPEC confirmation flow first (re-present draft, AskUserQuestion header "SPEC"), then re-run affected confirmations in order: 2a Rough Plan → 2b Detailed Plan → Results. If the feedback only affects implementation details or criterion tagging, revise the affected plan confirmations in order without re-opening SPEC.

Mark "Confirmation 3: Expected Results" as `completed`.

### 3b. Self-check: Requirements Coverage

Self-check after all confirmations: for EACH original requirement, verify at least one criterion covers it. Direction: requirement → criterion (NOT reverse).

If any lacks coverage: **stop**, alert user, ask whether to add or exclude. Proceed only after confirmation.

### 4. Write PLAN.md

Mark "Write PLAN.md & CRITERIA.md" as `in_progress`.

Only after all confirmations pass (triple confirmation for standard/quick/write, or single "Plan" confirmation for instant), write the complete plan to `.ca/workflows/<active_id>/PLAN.md`. If fix_round > 0, write to `.ca/workflows/<active_id>/rounds/<N>/PLAN.md`.

**CRITICAL — Verbatim Copy**: The PLAN.md content MUST be an exact copy of the confirmed plan — from Confirmation 2b for standard/quick/write workflows, or from the confirmed 3-instant Plan content for instant workflows, including ALL code blocks, before/after examples, line numbers, and step details. Do NOT regenerate, summarize, abbreviate, or rewrite any part of the confirmed plan. The user confirmed a specific version — that exact version must be written to the file.

```markdown
# Implementation Plan

## Requirement Summary
<from REQUIREMENT.md, or from BRIEF.md if quick/instant workflow>

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

Derive success criteria from SPEC.md's Verification Design section (for standard/quick/write workflows). For `workflow_type: instant`, derive criteria from the success criteria confirmed in the single "Plan" confirmation (step 3-instant) — there is no SPEC.md. Convert each test case into a verifiable criterion tagged `[auto]` or `[manual]`.

If file exists and fix_round > 0, append new fix-specific criteria below existing ones.
If the file does not exist, create it:

```
# Success Criteria

Derived from SPEC.md Verification Design (or from confirmed Plan criteria for instant workflows).

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

Mark "Write PLAN.md & CRITERIA.md" as `completed`.

### 5. Update STATUS.md

Set `plan_completed: true`, `plan_confirmed: true`, `current_step: plan`.
Also set `status_note` to a context-aware summary, e.g.: "Plan confirmed. Ready for execution." (fix mode: "Fix round N plan confirmed. Ready for execution.")

Tell the user the plan is confirmed. Suggest next steps:
- `/ca:execute` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Batch tip**: Plan multiple requirements first (`/ca:quick`/`/ca:new`), then `/ca:batch` to execute all.

**Do NOT auto-proceed.**
