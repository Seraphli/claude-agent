---
name: ca-verify
description: Independently verifies implementation against success criteria using verifier agents. Use when execution is complete.
---

# /ca:verify — Verify Results

**CRITICAL — Code Modification Policy**: Verify is READ-ONLY. Do NOT modify any source code or project files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root>`.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `execute_completed: true` from the parsed JSON. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

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
5. Create initial tasks:
   - `TaskCreate`: subject "Read context & parse criteria", activeForm "Reading context"
   - `TaskCreate`: subject "Present report & acceptance", activeForm "Presenting report"

Mark "Read context & parse criteria" as `in_progress`.

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

**CRITICAL — Verify is READ-ONLY**: Throughout the ENTIRE verify command lifecycle, you MUST NEVER:
- Modify any source code or project files
- Write fix plans, solutions, or suggestions for how to fix failures
- Call other skills (ca-plan, ca-execute, etc.)

**Exception — Auto-fix loop**: When `auto_fix: true` in config and conditions are met (see step 3d), verify MAY call `Skill(ca:plan)` after completing the failure handling flow. This is the ONLY permitted skill call, and only in this specific auto-fix condition.

You CAN and SHOULD read source code to understand the current state, verify criteria, and answer user questions about the implementation. The restriction is on WRITING changes, not on READING code.

This applies regardless of how the user communicates — whether through AskUserQuestion options, canceling option selection and typing directly, or any other interaction pattern. If the user asks about failures, you may read code to explain the current state, but guide them to use `/ca:plan` for actual fixes.

You are the verification orchestrator. You delegate the actual verification to the `ca-verifier` agent running in a **fresh context** to avoid confirmation bias.

### 1. Read context

Read `fix_round` from STATUS.md (default: 0 if not present).

Read these files and collect their full content:
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick`)
- `.ca/workflows/<active_id>/CRITERIA.md` (if exists)

If `fix_round` == 0:
- `.ca/workflows/<active_id>/PLAN.md`
- `.ca/workflows/<active_id>/SUMMARY.md`

If `fix_round` > 0 (current fix round N):
- `.ca/workflows/<active_id>/rounds/<N>/PLAN.md`
- `.ca/workflows/<active_id>/rounds/<N>/SUMMARY.md`

Parse the criteria into two groups based on `[auto]` and `[manual]` tags. Within each group, note the list structure (ordered = sequential, unordered = parallel) for execution planning.

Mark "Read context & parse criteria" as `completed`.

For each `[auto]` criterion, `TaskCreate`: subject "Auto: <criterion summary>", activeForm "Verifying: <summary>".
For each `[manual]` criterion (skip if `batch_mode: true` or `auto_fix_mode: true` in STATUS.md), `TaskCreate`: subject "Manual: <criterion summary>", activeForm "Verifying: <summary>".

### 2. Resolve model for ca-verifier

Read `ca-verifier_model` from the config JSON already loaded. This is the already-resolved model name (opus/sonnet/haiku). Pass to Task tool.

### 3. Execute auto verification

#### 3a. Parse auto criteria structure

Read the `[auto]` section from CRITERIA.md. Check the list structure:
- If **unordered list** with multiple items that can be split: go to 3c (parallel verification).
- Otherwise: go to 3b (single verifier).

#### 3b. Single verifier

Mark ALL auto criterion tasks as `in_progress`.

Launch a single `ca-verifier` agent with all `[auto]` criteria. The agent verifies each criterion and returns a report.

After verifier returns: mark each auto criterion task as `completed`.

#### 3c. Parallel verification (optional)

Read `max_concurrency` from the config JSON already loaded. If the number of parallel groups exceeds `max_concurrency`, split into batches of `max_concurrency` size and execute batches sequentially. For each batch, mark tasks in current batch as `in_progress`. Launch multiple `ca-verifier` agents **in the same message**, each handling a subset of `[auto]` criteria (based on the unordered list grouping). Each agent receives:
- Its assigned criteria
- All context files (REQUIREMENT.md/BRIEF.md, PLAN.md, SUMMARY.md)
- The project root path
- A unique output file path: `VERIFY-verifier-{N}.md`

Wait for all agents to complete. As each verifier returns: mark corresponding tasks as `completed`. Then merge reports.

#### 3d. Handle auto results

**Strict status parsing**: When reading verifier results, only exact `PASS` counts as passing. Any variant — "PASS (with issues)", "PASS (partial)", "PASS (unverified)", "CONDITIONAL PASS", etc. — MUST be treated as FAIL. If the verifier report contains any such variant, rewrite it to FAIL before proceeding with the pass/fail logic below.

If all auto criteria PASS: proceed to step 3e (manual verification).

If any auto criteria FAIL:

Check `batch_mode` in STATUS.md:

**If `batch_mode: true`**:
- Write VERIFY-REPORT.md (same path logic as normal mode based on fix_round).
- Do NOT retry or trigger fix. Report the failures and return failure status immediately.
- The batch orchestrator (batch.md) will handle rollback and continue to the next workflow.

**If `batch_mode` is false or not set (normal mode)**:
1. **Determine fix round**: Read `fix_round` from STATUS.md (default: 0). Set N = fix_round + 1.
2. **Create round directory**: Create `.ca/workflows/<active_id>/rounds/<N>/`.
3. **Write ISSUES.md**: Write `.ca/workflows/<active_id>/rounds/<N>/ISSUES.md`:
   ```markdown
   # Issues (Round N)

   ## From Verification Report
   <failed criteria with details>

   ## Additional User Feedback
   None
   ```
4. **Write VERIFY-REPORT.md**:
   - If N == 1 (first fix round): write to `.ca/workflows/<active_id>/VERIFY-REPORT.md`
   - If N > 1: write to `.ca/workflows/<active_id>/rounds/<N-1>/VERIFY-REPORT.md`
   The report MUST contain:
   - Which criteria failed and what the failure details are
   - References to any verifier output/log files
   - Do NOT include fix plans, suggestions, or solutions — only record the problems
5. **Update STATUS.md**: CRITICAL — Use `ca-status.js update` to ensure ALL fields are correctly reset. Run:
   ```
   node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js update --project-root <project-root> fix_round=<N> plan_completed=false plan_confirmed=false execute_completed=false verify_completed=false current_step=verify "status_note=Verification failed (round N): <brief failure summary>. Ready for fix planning."
   ```
   Do NOT use Write or Edit tools to update STATUS.md — the script handles type coercion and field updates correctly. Using Write/Edit may silently fail to reset fields.
6. **Auto-fix assessment**: Read `auto_fix` and `max_fix_rounds` from config.
   - If `auto_fix: false` or not set:
     a. Report the failures to the user (show the report summary).
     b. Suggest the user run `/ca:plan` (or `/ca:next`) to plan the fix.
     c. **Stop immediately.**
   - If `auto_fix: true`:
     a. **Assess fixability**: Analyze the failed criteria and their details. Determine whether the failures are:
        - **Implementation bugs** (code logic errors, missing implementation details, typos, wrong values, incomplete steps) — these are auto-fixable.
        - **Approach/plan issues** (fundamental design flaws, wrong architecture, missing requirements, need for new design decisions) — these require user intervention.
     b. If failures are **approach/plan issues** (NOT auto-fixable):
        - Report the failures with explanation: "These failures indicate approach/plan issues that require manual intervention."
        - Suggest the user run `/ca:plan` (or `/ca:next`).
        - **Stop immediately.**
     c. If failures are **implementation bugs** (auto-fixable) AND N <= `max_fix_rounds`:
        - Update STATUS.md to also set `auto_fix_mode=true`: run `node ... ca-status.js update --project-root <project-root> auto_fix_mode=true`
        - Report: "Auto-fix round N/max_fix_rounds: detected implementation bugs. Auto-generating fix plan..."
        - Call `Skill(ca:plan)`.
        - **Stop here.** Plan will chain to execute→verify.
     d. If failures are **implementation bugs** but N > `max_fix_rounds`:
        - Update STATUS.md to set `auto_fix_mode=false`: run `node ... ca-status.js update --project-root <project-root> auto_fix_mode=false`
        - Report: "Auto-fix loop reached maximum rounds (max_fix_rounds). Manual intervention required."
        - Suggest the user run `/ca:plan` (or `/ca:next`).
        - **Stop immediately.**

**CRITICAL — No Fixing in Verify**: The verify command MUST NEVER:
- Modify source code or project files
- Write fix plans, solutions, or suggestions in the report
- Reset STATUS.md or modify PLAN.md
- Call other skills — **EXCEPT** `Skill(ca:plan)` when auto-fix conditions are met (see step 3d)
- Re-run tests that already have logged output

You CAN read source code to understand the current state and explain issues to the user. The prohibition is on modifying code and proposing fixes, not on reading and understanding.

If the user raises issues or asks about failures, you may read code and explain the situation, but guide to `/ca:plan` for actual fixes. Never modify code within the verify context.

#### 3e. Manual verification

If `batch_mode: true` OR `auto_fix_mode: true` in STATUS.md: skip manual verification entirely and proceed to step 4.

Present all `[manual]` criteria to the user one at a time. For each:
- Mark "Manual: <criterion>" as `in_progress`.
- Describe what needs to be verified
- Use `AskUserQuestion` to ask the user to confirm PASS or FAIL:
  - **CRITICAL**: header MUST be exactly `"Manual"`
  - question: describe the criterion and ask for PASS/FAIL confirmation
  - options: "Pass" / "Fail"
- After user confirms Pass/Fail: mark "Manual: <criterion>" as `completed`.
- Record the result

After all manual criteria are verified, proceed to step 4.

### 4. Present verification report

Mark "Present report & acceptance" as `in_progress`.

Display the report with auto and manual sections:

```
## Verification Report

### Auto Results
| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | ... | PASS/FAIL | ... |

### Manual Results
| # | Criterion | Status | User Confirmation |
|---|-----------|--------|-------------------|
| 1 | ... | PASS/FAIL | ... |

### Overall: PASS/FAIL
```

**CRITICAL — Verify is READ-ONLY (Reminder)**: Even at the final acceptance step, you MUST NOT modify any source code, write fix plans, or call other skills. If the user rejects, record the issues and direct to `/ca:plan`. Do NOT attempt to fix anything.

### 5. MANDATORY CONFIRMATION — User Acceptance

If `batch_mode: true` OR `auto_fix_mode: true` in STATUS.md: skip user acceptance (auto criteria all passed = accepted) and proceed directly to step 6 (Update STATUS.md).

Use `AskUserQuestion` with:
- header: "Results"
- question: "Do you accept these results?"
- options:
  - "Accept" — "Results are satisfactory"
  - "Reject" — "Results need work"

- If the user **cancels and communicates directly**: Treat as Reject. Record feedback in VERIFY-REPORT.md, suggest `/ca:plan`. **Stop immediately.**
- If **Reject**:
  1. Ask what's wrong.
  2. **Determine fix round**: Read `fix_round` from STATUS.md (default: 0). Set N = fix_round + 1.
  3. **Create round directory**: Create `.ca/workflows/<active_id>/rounds/<N>/`.
  4. **Write ISSUES.md**: Write `.ca/workflows/<active_id>/rounds/<N>/ISSUES.md`:
     ```markdown
     # Issues (Round N)

     ## From User Feedback
     <user's rejection feedback>

     ## From Verification Report
     <any failed criteria from the report above, if applicable>
     ```
  5. **Write VERIFY-REPORT.md**:
     - If N == 1: write to `.ca/workflows/<active_id>/VERIFY-REPORT.md`
     - If N > 1: write to `.ca/workflows/<active_id>/rounds/<N-1>/VERIFY-REPORT.md`
  6. **Update STATUS.md**: CRITICAL — Use `ca-status.js update` to ensure ALL fields are correctly reset. Run:
     ```
     node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js update --project-root <project-root> fix_round=<N> plan_completed=false plan_confirmed=false execute_completed=false verify_completed=false current_step=verify "status_note=User rejected results (round N): <brief feedback>. Ready for fix planning."
     ```
     Do NOT use Write or Edit tools to update STATUS.md.
  7. Suggest `/ca:plan` (or `/ca:next`) for fix planning.
  8. **Stop immediately.** Do NOT fix, investigate, or modify code.
- If **Accept**: Proceed to step 6.

### 6. Update STATUS.md

Mark "Present report & acceptance" as `completed`.

Set `verify_completed: true`, `current_step: verify`.

If `auto_fix_mode: true` in STATUS.md: also update STATUS.md to set `auto_fix_mode=false` (clear the flag since verification passed).

Also set `status_note`, e.g.: "Verification passed. Ready for finish."

Tell the user verification is complete. Suggest next steps:
- `/ca:finish` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
