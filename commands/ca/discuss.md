---
name: ca-discuss
description: Researches and discusses requirements through adaptive Q&A. Use when requirements need clarification before planning.
---
# /ca:discuss — Discuss Requirements

**CRITICAL — Code Modification Policy**: This command is for research and discussion ONLY. Do NOT modify any source code or project files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

### Resolve workflow ID

Determine which workflow to operate on using this priority:

1. **Context inference**: If the current conversation has already been working with a specific workflow (e.g., you just ran `/ca:quick` or `/ca:plan` for it earlier in this session), use that workflow ID.
2. **Single workflow**: Run `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. If exactly one workflow exists, use it automatically.
3. **Multiple workflows**: If multiple workflows exist, present them to the user and ask which one to operate on:
   - `AskUserQuestion`: header "[W.Workflow]", question "Which workflow do you want to discuss?", options: list each workflow (label: workflow ID, description: "<workflow_type>, step: <current_step>")
4. **No workflows**: If no workflows exist, tell the user to run `/ca:new` first and stop.

After resolving `<active_id>`:

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root> --workflow-id <active_id>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Check `workflow_type` from the parsed JSON. If `workflow_type: quick` or `workflow_type: instant`, tell the user: "This is a quick/instant workflow. The discuss step is skipped. Please proceed with `/ca:plan`." **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

**Flow-gate header prefix**: Every `AskUserQuestion` in this command uses a structural header prefix. Both the prefix AND the stage word are ALWAYS English — never localized, regardless of `interaction_language`. Discuss gates: `[D.Clarify]`, `[D.Reqs]`, `[D.SPEC]`, `[D.Research]`, `[D.Directions]`, `[D.ADR]`. Shared gates: `[W.Workflow]`, `[W.Tasks]`.

Goal: understand **exactly** what the user wants before code is written.

### 0. Task cleanup and initialization

1. Call `TaskList` to get all existing tasks.
2. If no tasks exist, skip to step 5.
3. If ALL tasks are `completed`: call `TaskUpdate` with `status: "deleted"` for each task.
4. If any task is NOT `completed` (pending or in_progress):
   a. Call `TaskGet` for each uncompleted task.
   b. Analyze possible causes by cross-referencing with STATUS.md (e.g., session interrupted, phase skipped, abnormal exit).
   c. Present to user: list each uncompleted task with subject, status, and possible cause.
   d. `AskUserQuestion`: header "[W.Tasks]", question "There are uncompleted tasks from the previous phase. How to proceed?", options:
      - "Clear and continue" — "Delete all old tasks and start current phase"
      - "Stop" — "Pause to investigate the previous phase's issues"
   e. If "Clear and continue": call `TaskUpdate` with `status: "deleted"` for ALL tasks.
   f. If "Stop": stop current command immediately.
5. Create initial tasks:
   - `TaskCreate`: subject "Assess requirement", activeForm "Assessing requirement"
   - `TaskCreate`: subject "Confirm requirements", activeForm "Confirming requirements"
   - `TaskCreate`: subject "Create SPEC", activeForm "Creating SPEC"

Mark "Assess requirement" as `in_progress`.

### 1. Adaptive Research

#### 1a. Resolve model for ca-researcher

Read `ca-researcher_model` from the config JSON already loaded. This is the already-resolved model name (opus/sonnet/haiku). Pass to agents launched in step 1d.

#### 1b. Assess requirement and decide approach

Read BRIEF.md and `.ca/map.md` (if exists). Assess two things:

1. **Requirement clarity**: Is the requirement description clear enough to determine what to research? Or is it too vague to even know where to start?
2. **Approach confidence**: Based on your current knowledge, do you already have a rough idea of how to implement this?

Based on your assessment, follow ONE of these paths:

**Path A — Requirement is vague** (unclear scope, ambiguous goals, not enough detail to determine research directions):
- Ask 1-3 focused preliminary questions to clarify the requirement scope. Use `AskUserQuestion` where appropriate.
- After the user's answers provide enough clarity, proceed to step 1c.

**Path B — Requirement is clear but approach is uncertain** (you know what the user wants, but don't know how to achieve it):
- Proceed directly to step 1c.

**Path C — Requirement is clear and approach is roughly known** (you have a reasonable idea of what to do):
- Present your preliminary approach briefly (2-3 sentences describing what you'd do).
- Proceed to step 1c (where the user can choose to skip research).

Mark "Assess requirement" as `completed`.

#### 1c. Research confirmation

Based on your understanding of the requirement, propose research directions. The goal is to fill knowledge gaps needed to form a solid plan.

**For new features**: You MAY use the 4 standard dimensions (Stack, Features, Architecture, Pitfalls) as a starting template. However, you SHOULD also consider whether task-specific directions would be more useful, and you MAY replace or supplement the standard dimensions.

**For all other types** (bug fix, refactoring, docs, creative, etc.): Generate 2-4 task-specific research directions based on what you actually need to learn for THIS requirement. Do NOT use fixed templates. Examples:
- "Investigate the authentication flow in module X to understand current behavior"
- "Check how the config system resolves values across tiers"
- "Research common plot structures for mystery novels"

Present the research directions to the user, along with context:
- If Path C (approach known): mention that you already have a rough approach and research may not be essential, but these directions could help confirm or refine it.
- If Path A/B: explain what you're uncertain about and why these directions would help.

Use `AskUserQuestion`:
- header: "[D.Research]"
- question: "Here are the research directions I'd suggest. How would you like to proceed?"
- options:
  - "Run all (<N>)" — "Research all <N> proposed directions"
  - "Select directions" — "Choose which directions to research"
  - "Skip research" — "Skip research, go straight to discussion"

**If Run all**: Proceed to step 1d with all directions.
**If Skip research**: `TaskCreate`: subject "Research (skipped)", activeForm "Skipping research". Mark it immediately as `completed`. Skip steps 1d and 1e. Proceed to step 2.
**If Select directions**: Use `AskUserQuestion` with `multiSelect: true`:
  - header: "[D.Directions]"
  - question: "Select which directions to research:"
  - options: (the proposed directions, max 4)
  - If user selects none (Other with skip intent): treat as Skip research.
  - Otherwise: proceed to step 1d with selected directions only.

For each confirmed research direction, `TaskCreate`: subject "Research: <direction name>", activeForm "Researching <direction name>".

#### 1d. Launch researchers

Launch ca-researcher agents **only for the directions confirmed by the user**. Use resolved model from step 1a. Pass each agent:
- The full content of BRIEF.md
- The project root path
- The content of `.ca/map.md` (if exists)
- The specific research prompt for each direction

Launch in parallel (up to `max_concurrency`). Mark the corresponding "Research: <direction name>" task as `in_progress` when launching each agent.

#### 1e. Present research findings

As each researcher agent returns, mark the corresponding "Research: <direction name>" task as `completed`. After all agents complete, present a merged summary organized by research direction.

### 2. Start the discussion

Read BRIEF.md as the starting point. Also read `.ca/map.md` (if exists) for project context. Incorporate any task description provided with this command. If no brief or description exists, ask what they want. Also read `.ca/docs/CONTEXT.md` (if exists) — the project terminology glossary. Use it to recognize already-defined terms and to detect conflicts during grilling.

### 3. Grill Interview (relentless, decision-tree)

`TaskCreate`: subject "Grill interview", activeForm "Grilling requirements". Mark as `in_progress`.

Conduct the requirement clarification as a relentless grilling interview, NOT a one-shot dimension dump. Core directive (verbatim):

> Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer. Ask the questions one at a time, waiting for feedback on each question before continuing. If a question can be answered by exploring the codebase, explore the codebase instead.

**Session behaviors (apply throughout):**
1. **Challenge term conflicts** against `.ca/docs/CONTEXT.md` immediately. "Your glossary defines X as A, but you seem to mean B — which is it?"
2. **Sharpen fuzzy/overloaded language** — propose a precise canonical term.
3. **Stress-test domain boundaries** with concrete invented scenarios that force precision.
4. **Cross-reference claims against actual code**; surface contradictions you find.
5. **Update CONTEXT.md inline** as each term resolves (do NOT batch) — see step 3b.
6. **Capture domain terms for CONTEXT.md** — when the user's requirement or answers introduce a project/domain term that is semantically ambiguous or will be reused across the project (e.g. Salutation as a greeting prefix), proactively confirm it as a canonical glossary term with the user and write it to CONTEXT.md immediately, before continuing to the next clarification question. Do not wait for the user to raise the term — if you see such a term that is not yet in CONTEXT.md, ask about it. Exclude generic programming concepts, language/framework names, and CA workflow terms (e.g. workflow, criterion, phase) unless the user specifies they carry a project-specific meaning.

**Explore-instead-of-ask (hybrid):** for code-answerable questions, do quick Read/Grep point lookups inline; for large unknowns, dispatch a `ca-researcher` agent (resolved model from step 1a); put only genuine preference/tradeoff decisions to the user. Always provide a recommended answer (for `AskUserQuestion`, put `(Recommended)` at the end of the suggested option label; reserve plain text for open-ended questions).

**Ask ONE question at a time.** Each grill clarification `AskUserQuestion` MUST use the exact header `[D.Clarify]` (English only, never localized) so the clarification stage is identifiable by header; put the topic-specific content in the question text, NOT the header. For each question, `TaskCreate`: subject "Clarify: <brief>", activeForm "Clarifying <brief>"; mark `in_progress`; after the user answers, mark `completed`. If the user signals they don't understand, STOP and rephrase the current question before moving on (Discussion Completeness Rule).

**Internal coverage checklist (do NOT present as a table):** ensure the grilling covers — Functional Scope & Behavior; Domain & Data Model; Interaction & UX Flow; Non-Functional Quality; Integration & Dependencies; Edge Cases & Error Handling; Constraints & Tradeoffs; Terminology & Consistency; Completion Signals; Misc & Ambiguity. (Write workflows: Scope & Goal; Audience & Tone; Structure & Flow; Research & References; Terminology & Consistency; Constraints.) Keep grilling until every relevant checklist item is resolved.

**Post-grill CONTEXT.md check**: Before marking the grill interview as completed, verify that every canonical term resolved during grilling has been written to `.ca/docs/CONTEXT.md`. If any resolved term is missing (e.g. because it was discussed but the write was skipped), write it now using the format in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/context-format.md`. This is a safety net — inline writes (behavior 6 / step 3b) should have already captured them, but this check ensures nothing is lost.

Mark "Grill interview" as `completed`.

### 3b. Update CONTEXT.md inline

When — and only when — the user confirms a canonical term and its definition during grilling, write/update `.ca/docs/CONTEXT.md` immediately (create lazily on the first resolved term) using the grill glossary format in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/context-format.md`. A merely-recommended-but-unanswered question is NOT written. On conflict resolution, update the affected entry and its `_Avoid_` list in place. CONTEXT.md is a glossary only — no implementation details.

### 3c. Record decisions in TRACKING.md

As decisions crystallize during grilling, append them to `.ca/workflows/<active_id>/TRACKING.md` (create lazily) under `## Decisions`, per `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/tracking-format.md`: what was chosen, what was rejected, and why (user preferences). Do NOT duplicate content captured elsewhere.

### 3d. Offer ADR for significant decisions

After recording a decision in TRACKING.md, check if it meets ALL THREE conditions from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/references/adr-format.md` (hard to reverse + surprising without context + a real trade-off). If yes, OFFER to record an ADR:

`AskUserQuestion`: header `"[D.ADR]"`, question "Record this decision as an ADR?", options "Yes"/"No".

On "Yes": write `.ca/docs/adr/NNNN-slug.md` (next sequential number, grill format). Do NOT auto-create; trivial decisions are not offered. Record the offered/created ADR in TRACKING.md under `## Decisions` (e.g. "[ADR] 0001-rest-vs-graphql.md created").

### 5. Present requirement summary

Mark "Confirm requirements" as `in_progress`.

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

### 6. MANDATORY CONFIRMATION

Use `AskUserQuestion` with:
- header: "[D.Reqs]"
- question: "Does this accurately capture your requirements?"
- options:
  - "Accurate" — "Requirements are correct, proceed"
  - "Needs changes" — "I want to revise something"

- If **Accurate**: Mark "Confirm requirements" as `completed`. Write the summary to `.ca/workflows/<active_id>/REQUIREMENT.md`.

Mark "Create SPEC" as `in_progress`.

### 6b. Create SPEC

Based on the confirmed requirements and any research findings from earlier steps, draft a SPEC document with two sections:

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

2. **Verification Design**: Each test case (TC) is a **behavioral test** — it DESCRIBES the runnable behavior under test (the user path / inputs / observable outputs), NOT a static inspection of source files. Each TC MUST specify:
   - **Target test**: which test the behavior lands in. **If the project already has a test suite (e.g., `tests/phases/`) and this requirement supplements tests, name the concrete test file to add/modify and how it changes.** If no suite exists yet, state which test file to create.
   - **Behavior**: the concrete scenario — setup/preconditions, the operation or input that is driven, and the expected observable output.
   - **Feasible & testable**: the expected output MUST be something a run can decide PASS/FAIL deterministically. NEVER write a TC whose pass/fail cannot be determined by running it.

   Describe the behavior only; **do NOT write the actual test code here** — the real test code is written later by the executor during `/ca:execute`.

   **FORBIDDEN** (these are NOT valid test cases):
   > (a) Using a static inspection of the implementation/source as the test — e.g. "grep `plan.md` for 'CRITICAL.*SPEC Detail'; assert match". That tests implementation text, not behavior, and is indistinguishable from a verification criterion.
   > (b) A TC whose result cannot actually be tested — e.g. "verify the wording reads well" or any subjective judgment.
   > (c) Writing the complete test script/code inside the SPEC.

   **CORRECT** (behavioral test description):
   > "Target test: extend `tests/phases/phase1_quick.sh`. Behavior: run a quick workflow whose requirement adds `greet(name)` to `utils.js`; after `/ca:plan` generates `SPEC.md`, assert the generated `SPEC.md`'s Verification Design describes a runnable check of `greet` (a concrete invocation with expected output), not a `grep`-and-match line. PASS/FAIL is decided deterministically by grepping the produced `SPEC.md`."

Prioritize E2E/behavior-level tests that recreate the user's real usage path. Unit/integration tests may supplement but should not replace user-experience verification. **Do NOT write complete test scripts/code in the SPEC** — describe the test's target file, setup, operation, and expected output clearly enough for the executor to implement it during `/ca:execute`.

Present the draft SPEC to the user:

```
## SPEC Draft

### Desired Result / User Experience
<content>

### Verification Design
<test cases as action + assertion>
```

`AskUserQuestion`: header "[D.SPEC]", question "Does this SPEC accurately describe the desired result and verification design?", options "Accurate"/"Needs changes".

If **Needs changes**: ask what needs to change, revise, re-confirm.
If **Accurate**: Write the SPEC to `.ca/workflows/<active_id>/SPEC.md`:

```markdown
# SPEC

## Desired Result / User Experience
<confirmed content>

## Verification Design
<confirmed content>
```

Mark "Create SPEC" as `completed`.

Update STATUS.md (`discuss_completed: true`, `current_step: discuss`). Also set `status_note` to a context-aware summary, e.g.: "Requirements discussed and confirmed. SPEC created. Ready for planning." Tell the user discussion is complete. Suggest next steps:
- `/ca:plan` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

- If **Needs changes**: Ask what needs to change, revise the summary, and ask for confirmation again.

**Do NOT auto-proceed.**
