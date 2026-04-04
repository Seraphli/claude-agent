---
name: ca-discuss
description: Researches and discusses requirements through adaptive Q&A. Use when requirements need clarification before planning.
---
# /ca:discuss — Discuss Requirements

**CRITICAL — Code Modification Policy**: This command is for research and discussion ONLY. Do NOT modify any source code or project files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Check `workflow_type` from the parsed JSON. If `workflow_type: quick`, tell the user: "This is a quick workflow. The discuss step is skipped. Please proceed with `/ca:plan`." **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

Goal: understand **exactly** what the user wants before code is written.

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
- header: "Research"
- question: "Here are the research directions I'd suggest. How would you like to proceed?"
- options:
  - "Run all (<N>)" — "Research all <N> proposed directions"
  - "Select directions" — "Choose which directions to research"
  - "Skip research" — "Skip research, go straight to discussion"

**If Run all**: Proceed to step 1d with all directions.
**If Skip research**: Skip steps 1d and 1e. Proceed to step 2.
**If Select directions**: Use `AskUserQuestion` with `multiSelect: true`:
  - header: "Directions"
  - question: "Select which directions to research:"
  - options: (the proposed directions, max 4)
  - If user selects none (Other with skip intent): treat as Skip research.
  - Otherwise: proceed to step 1d with selected directions only.

#### 1d. Launch researchers

Launch ca-researcher agents **only for the directions confirmed by the user**. Use resolved model from step 1a. Pass each agent:
- The full content of BRIEF.md
- The project root path
- The content of `.ca/map.md` (if exists)
- The specific research prompt for each direction

Launch in parallel (up to `max_concurrency`).

#### 1e. Present research findings

After all agents complete, present a merged summary organized by research direction.

### 2. Start the discussion

Read BRIEF.md as the starting point. Also read `.ca/map.md` (if exists) for project context. Incorporate any task description provided with this command. If no brief or description exists, ask what they want.

### 3. Systematic dimension scan

After research findings are available (or after step 2 if research was skipped), scan the requirement against all relevant dimensions.

**Standard workflow (workflow_type: standard) — 10 dimensions:**

| # | Dimension | Focus |
|---|-----------|-------|
| 1 | Functional Scope & Behavior | What exactly should happen? Inputs, outputs, expected behavior |
| 2 | Domain & Data Model | Entities, data structures, relationships, formats |
| 3 | Interaction & UX Flow | User interaction paths, UI/CLI flow, feedback |
| 4 | Non-Functional Quality | Performance, security, reliability, readability |
| 5 | Integration & Dependencies | External systems, APIs, libraries, file dependencies |
| 6 | Edge Cases & Error Handling | Boundary conditions, failure modes, error recovery |
| 7 | Constraints & Tradeoffs | Technical limits, backward compatibility, acceptable compromises |
| 8 | Terminology & Consistency | Naming conventions, style consistency with existing content |
| 9 | Completion Signals | How to verify "done"? Measurable acceptance criteria |
| 10 | Misc & Ambiguity Scan | Vague adjectives ("appropriate", "reasonable"), TODO placeholders |

**Write workflow (workflow_type: write) — 6 dimensions:**

| # | Dimension | Focus |
|---|-----------|-------|
| 1 | Scope & Goal | What to write/modify? Core objective |
| 2 | Audience & Tone | Target reader, style, formality level |
| 3 | Structure & Flow | Outline, section organization, logical progression |
| 4 | Research & References | Sources, citations, background material needed |
| 5 | Terminology & Consistency | Term usage, consistency with existing content |
| 6 | Constraints | Length limits, format requirements, platform rules |

For each dimension, assess:
- **Clear**: requirement already covers this sufficiently
- **Partial**: some information exists but gaps remain
- **Missing**: no information about this dimension

Present the assessment as a table to the user:
```
| Dimension | Status | Note |
|-----------|--------|------|
| Functional Scope & Behavior | Clear | ... |
| Domain & Data Model | Partial | Need to clarify X |
| ... | ... | ... |
```

### 4. Ask clarifying questions ONE AT A TIME

Generate questions ONLY from dimensions marked Partial or Missing. Sort by Impact × Uncertainty (highest first). Ask ONE question at a time. Typically 2-5 questions suffice.

**IMPORTANT**: If the user indicates they don't understand your question, you MUST stop and explain or rephrase the current question. Do NOT move on to the next question until the current one is resolved. Follow the Discussion Completeness Rule in `_rules.md`.

Use `AskUserQuestion` for questions with clear options. For questions with clear options, add a recommended option: place `(Recommended)` at the end of the suggested option label.

Reserve plain text for open-ended questions.

**Supplementary Research**: During discussion, if new uncertainties emerge that need investigation, propose additional research directions to the user and launch ca-researcher agents after confirmation. Use the resolved model from step 1a when launching agents. Research is not limited to step 1 — it can happen at any point during discussion when knowledge gaps are identified.

**IMPORTANT**: Research MUST use `ca-researcher` agents (via the Agent tool with subagent_type ca-researcher). Do NOT use Explore agents, claude-code-guide, or general-purpose agents as a substitute for ca-researcher during any research phase in this command.

### 5. Present requirement summary

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
Update STATUS.md (`discuss_completed: true`, `current_step: discuss`). Also set `status_note` to a context-aware summary, e.g.: "Requirements discussed and confirmed. Ready for planning." Tell the user discussion is complete. Suggest next steps:
- `/ca:plan` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

- If **Needs changes**: Ask what needs to change, revise the summary, and ask for confirmation again.

**Do NOT auto-proceed.**
