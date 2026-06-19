---
name: ca-verify
description: Independently verifies implementation against success criteria using verifier agents. Use when execution is complete.
---

# /ca:verify — Verify Results

**CRITICAL — Code Modification Policy**: Verify is READ-ONLY with respect to source/project code. Verify MUST NOT modify source code or project files. However, verify DOES write workflow ledger files under `.ca/` — specifically: VERIFY.csv (result fields), VERIFY-REPORT.md, ISSUES.md, STATUS.md, and TRACKING.md. These `.ca/` workflow-ledger writes are explicitly permitted and required.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`.

### Resolve workflow ID

Determine which workflow to operate on using this priority:

1. **Context inference**: If the current conversation has already been working with a specific workflow (e.g., you just ran `/ca:quick` or `/ca:plan` for it earlier in this session), use that workflow ID.
2. **Single workflow**: Run `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js list --project-root <project-root>`. If exactly one workflow exists, use it automatically.
3. **Multiple workflows**: If multiple workflows exist, present them to the user and ask which one to operate on:
   - `AskUserQuestion`: header "[W.Workflow]", question "Which workflow do you want to verify?", options: list each workflow (label: workflow ID, description: "<workflow_type>, step: <current_step>")
4. **No workflows**: If no workflows exist, tell the user to run `/ca:new` or `/ca:quick` first and stop.

After resolving `<active_id>`:

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root> --workflow-id <active_id>`.
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
   d. `AskUserQuestion`: header "[W.Tasks]", question "There are uncompleted tasks from the previous phase. How to proceed?", options:
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

**CRITICAL — Verify write boundary**: Throughout the ENTIRE verify command lifecycle, you MUST NEVER:
- Modify any source code or project files
- Write fix plans, solutions, or suggestions for how to fix failures
- Call other skills (ca-plan, ca-execute, etc.)

**Permitted `.ca/` writes**: Verify DOES write the following workflow ledger files (these are required, not forbidden):
- `VERIFY.csv` — update `result` and `last_verified_round` fields for auto criteria (orchestrator single-writer)
- `rounds/<fix_round>/VERIFY-REPORT.md` — per-round verification report
- `rounds/<fix_round>/ISSUES.md` — issues discovered in the current round (discovering-round semantics)
- `STATUS.md` — via `ca-status.js update` only
- `TRACKING.md` — append round summary

**Exception — Auto-fix loop**: When `auto_fix: true` in config and conditions are met (see step 3d), verify MAY call `Skill(ca:plan)` after completing the failure handling flow. This is the ONLY permitted skill call, and only in this specific auto-fix condition.

You CAN and SHOULD read source code to understand the current state, verify criteria, and answer user questions about the implementation. The restriction is on WRITING source/project changes, not on READING code.

This applies regardless of how the user communicates — whether through AskUserQuestion options, canceling option selection and typing directly, or any other interaction pattern. If the user asks about failures, you may read code to explain the current state, but guide them to use `/ca:plan` for actual fixes.

You are the verification orchestrator. You delegate the actual verification to the `ca-verifier` agent running in a **fresh context** to avoid confirmation bias.

### 1. Read context

Read `fix_round` from STATUS.md (default: 0 if not present).

Read the root `VERIFY.csv` via:
```
node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js get --file .ca/workflows/<active_id>/VERIFY.csv --json
```

Parse rows into two groups:
- **`auto`**: rows where `method` is `auto` (includes both `type: self_check` and `type: test`)
- **`manual`**: rows where `method` is `manual`

Read these files and collect their full content:
- `.ca/workflows/<active_id>/REQUIREMENT.md` (or `.ca/workflows/<active_id>/BRIEF.md` if `workflow_type: quick` or `workflow_type: instant`)
- `.ca/workflows/<active_id>/rounds/<fix_round>/PLAN.md` (for ALL rounds, including round 0)
- `.ca/workflows/<active_id>/rounds/<fix_round>/SUMMARY.md` (for ALL rounds, including round 0)
- `.ca/workflows/<active_id>/rounds/<fix_round>/TASKS.csv` — pass its task rows to the verifier for the plan-compliance check

Read `worktree_path` from STATUS.md. If present, this is the **code working directory** — verifier agents should read/verify source code here, not at `<project-root>`. The orchestrator continues using `<project-root>` for all `.ca/` file operations.

Also read `project_worktrees` from STATUS.md for passing to verifier agents.

Mark "Read context & parse criteria" as `completed`.

For each `auto` criterion row, `TaskCreate`: subject "Auto: <criterion summary>", activeForm "Verifying: <summary>".
For each `manual` criterion row (skip if `batch_mode: true` or `auto_fix_mode: true` in STATUS.md, AND the row's `result` is already `pass` — see §3e), `TaskCreate`: subject "Manual: <criterion summary>", activeForm "Verifying: <summary>".

### 2. Resolve model for ca-verifier

Read `ca-verifier_model` from the config JSON already loaded. This is the already-resolved model name (opus/sonnet/haiku). Pass to Task tool.

### 3. Execute auto verification

#### 3a. Parse auto criteria structure

Read the `auto` rows parsed from VERIFY.csv. Check the count:
- If multiple `auto` rows that can be verified independently: go to 3c (parallel verification).
- Otherwise: go to 3b (single verifier).

#### 3b. Single verifier

Mark ALL auto criterion tasks as `in_progress`.

Launch a single `ca-verifier` agent with all `auto` criteria rows (full re-verify every round). Pass:
- All `auto` VERIFY.csv rows (id, type, description, acceptance)
- REQUIREMENT.md/BRIEF.md content
- PLAN.md and SUMMARY.md content from `rounds/<fix_round>/`
- TASKS.csv rows from `rounds/<fix_round>/TASKS.csv` (for plan-compliance check)
- The code working directory: `worktree_path` if present, otherwise `<project-root>`

The agent verifies each criterion and returns a report. Instruct the verifier to ALSO surface any newly-discovered problems beyond the defined criteria (problems the implementation has that are not yet captured as VERIFY.csv rows).

After verifier returns: mark each auto criterion task as `completed`.

#### 3c. Parallel verification (optional)

Read `max_concurrency` from the config JSON already loaded. If the number of parallel groups exceeds `max_concurrency`, split into batches of `max_concurrency` size and execute batches sequentially. For each batch, mark tasks in current batch as `in_progress`. Launch multiple `ca-verifier` agents **in the same message**, each handling a subset of `auto` criteria rows. Each agent receives:
- Its assigned criteria rows (id, type, description, acceptance)
- All context files (REQUIREMENT.md/BRIEF.md, rounds/<fix_round>/PLAN.md, rounds/<fix_round>/SUMMARY.md)
- TASKS.csv rows from `rounds/<fix_round>/TASKS.csv`
- The code working directory: `worktree_path` if present, otherwise `<project-root>`
- A unique output file path: `VERIFY-verifier-{N}.md`
- Instruction to surface any newly-discovered problems beyond defined criteria

Wait for all agents to complete. As each verifier returns: mark corresponding tasks as `completed`. Then merge reports.

#### 3d. Handle auto results

**Strict status parsing**: When reading verifier results, only exact `PASS` counts as passing. Any variant — "PASS (with issues)", "PASS (partial)", "PASS (unverified)", "CONDITIONAL PASS", etc. — MUST be treated as FAIL. If the verifier report contains any such variant, rewrite it to FAIL before proceeding with the pass/fail logic below.

**ORCHESTRATOR writes VERIFY.csv results** (single-writer): after collecting all verifier reports, update each `auto` row's result via:
```
node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update \
  --file .ca/workflows/<active_id>/VERIFY.csv \
  --id <vN> --field result --value pass|fail
node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update \
  --file .ca/workflows/<active_id>/VERIFY.csv \
  --id <vN> --field last_verified_round --value <fix_round>
```
Run these sequentially for each auto row. Do NOT let verifier agents write VERIFY.csv.

If all auto criteria PASS: proceed to step 3e (manual verification).

If any auto criteria FAIL:

**CRITICAL — All Failures Are Actionable**:
- NEVER dismiss a failure as "unrelated to current changes" or "pre-existing issue" — if it FAILs, it must be investigated and fixed
- NEVER ask the user "do you accept these results?" or "is this acceptable?" when there are FAIL criteria
- NEVER proceed to step 3e (manual verification), step 4, or step 5
- ALL failures require entering the fix round flow below — no exceptions

Check `batch_mode` in STATUS.md:

**If `batch_mode: true`**:
- Write VERIFY-REPORT.md to `.ca/workflows/<active_id>/rounds/<fix_round>/VERIFY-REPORT.md`.
- Do NOT retry or trigger fix. Report the failures and return failure status immediately.
- The batch orchestrator (batch.md) will handle rollback and continue to the next workflow.

**If `batch_mode` is false or not set (normal mode)**:

**CRITICAL — Clean up tasks before entering fix round**: Call `TaskList` and mark ALL remaining tasks (pending or in_progress) as `deleted` using `TaskUpdate`. This prevents the next phase (plan) from seeing stale tasks and prompting "uncompleted tasks from the previous phase".

1. **Write VERIFY-REPORT.md**: Write to `.ca/workflows/<active_id>/rounds/<fix_round>/VERIFY-REPORT.md`. The report MUST contain:
   - Which criteria failed and what the failure details are
   - References to any verifier output/log files
   - Do NOT include fix plans, suggestions, or solutions — only record the problems
2. **Write ISSUES.md**: Write `.ca/workflows/<active_id>/rounds/<fix_round>/ISSUES.md` (the DISCOVERING round — current `fix_round`, NOT `fix_round+1`):
   ```markdown
   # Issues (Round <fix_round>)

   ## From Verification Report
   <failed criteria with details>

   ## Additional User Feedback
   None
   ```
3. **Determine next fix round**: Set N = fix_round + 1.
4. **Update STATUS.md**: CRITICAL — Use `ca-status.js update` to ensure ALL fields are correctly reset. Run:
   ```
   node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js update --project-root <project-root> --workflow-id <active_id> fix_round=<N> plan_completed=false plan_confirmed=false execute_completed=false verify_completed=false current_step=verify "status_note=Verification failed (round <fix_round>): <brief failure summary>. Ready for fix planning."
   ```
   Do NOT use Write or Edit tools to update STATUS.md — the script handles type coercion and field updates correctly. Using Write/Edit may silently fail to reset fields.
5. **Append to TRACKING.md**: Append the round's result to `.ca/workflows/<active_id>/TRACKING.md`:
   ```markdown
   ### Round <fix_round>
   **Verify**: FAIL — <N_fail> failed, <N_pass> passed. Discovered problems: <list or "none">. Fix round <N> initiated.
   ```
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
        - Update STATUS.md to also set `auto_fix_mode=true`: run `node ... ca-status.js update --project-root <project-root> --workflow-id <active_id> auto_fix_mode=true`
        - Report: "Auto-fix round N/max_fix_rounds: detected implementation bugs. Auto-generating fix plan..."
        - Call `Skill(ca:plan)`.
        - **Stop here.** Plan will chain to execute→verify.
     d. If failures are **implementation bugs** but N > `max_fix_rounds`:
        - Update STATUS.md to set `auto_fix_mode=false`: run `node ... ca-status.js update --project-root <project-root> --workflow-id <active_id> auto_fix_mode=false`
        - Report: "Auto-fix loop reached maximum rounds (max_fix_rounds). Manual intervention required."
        - Suggest the user run `/ca:plan` (or `/ca:next`).
        - **Stop immediately.**

**CRITICAL — No Source Editing in Verify**: The verify command MUST NEVER:
- Modify source code or project files
- Write fix plans, solutions, or suggestions in the report
- Reset STATUS.md or modify PLAN.md (except via permitted ca-status.js update)
- Call other skills — **EXCEPT** `Skill(ca:plan)` when auto-fix conditions are met (see step 3d)
- Re-run tests that already have logged output
- Offer to "fix directly", "fix now", or ask "should I fix this?" — ALL fixes MUST go through `/ca:plan`

You CAN read source code to understand the current state and explain issues to the user. The prohibition is on modifying source/project code and proposing fixes, not on reading and understanding.

If the user raises issues or asks about failures, you may read code and explain the situation, but guide to `/ca:plan` for actual fixes. Never modify code within the verify context.

#### 3e. Manual verification

**Manual no-false-green guard**: Before skipping manual verification, check each `manual` row in VERIFY.csv:
- A `manual` row with `result: pass` MAY be retained in an auto-fix round (skip re-asking) — its `last_verified_round` makes the retained pass traceable.
- A `manual` row with `result: pending` or `result: fail` MUST be verified by the user. The workflow MUST NOT be marked verify-complete via the auto-fix path while any `manual` row is `pending` or `fail`. In that case, skip the `auto_fix_mode` shortcut and return to a normal verify requiring user confirmation.

If `batch_mode: true` in STATUS.md: skip manual verification entirely and proceed to step 3f.

If `auto_fix_mode: true` in STATUS.md AND all `manual` rows have `result: pass`: skip manual verification and proceed to step 3f.

If `auto_fix_mode: true` in STATUS.md AND any `manual` row has `result: pending` or `result: fail`: proceed with manual verification below (override the auto_fix_mode skip).

Present all `manual` criteria that are `pending` or `fail` to the user one at a time. For each:
- Mark "Manual: <criterion>" as `in_progress`.
- Describe what needs to be verified
- Use `AskUserQuestion` to ask the user to confirm PASS or FAIL:
  - **CRITICAL**: header MUST be exactly `"[V.Manual]"`
  - question: describe the criterion and ask for PASS/FAIL confirmation
  - options: "Pass" / "Fail"
- After user confirms Pass/Fail: update the row in VERIFY.csv via:
  ```
  node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update \
    --file .ca/workflows/<active_id>/VERIFY.csv \
    --id <vN> --field result --value pass|fail
  node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js update \
    --file .ca/workflows/<active_id>/VERIFY.csv \
    --id <vN> --field last_verified_round --value <fix_round>
  ```
- Mark "Manual: <criterion>" as `completed`.
- Record the result.

After all manual criteria are verified (or skipped per the guards above), check manual results:

**If ANY `manual` row has `result: fail`** (newly set in this run or carried over from prior round):

Treat the failure equivalently to an auto-fail per §3d. Do NOT proceed to §3f, §4, or §5.

1. **Write VERIFY-REPORT.md** to `.ca/workflows/<active_id>/rounds/<fix_round>/VERIFY-REPORT.md` containing the failed manual criteria (id, criterion text, user's Fail confirmation).
2. **Write ISSUES.md** to the discovering round: `.ca/workflows/<active_id>/rounds/<fix_round>/ISSUES.md`:
   ```markdown
   # Issues (Round <fix_round>)

   ## From Verification Report — Failed Manual Criteria
   <list of manual rows with result=fail and the criterion text>
   ```
3. **Determine next fix round**: Set N = fix_round + 1.
4. **Update STATUS.md**:
   ```
   node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js update --project-root <project-root> --workflow-id <active_id> fix_round=<N> plan_completed=false plan_confirmed=false execute_completed=false verify_completed=false current_step=verify "status_note=Manual verification failed (round <fix_round>): <list of failed criteria>. Ready for fix planning."
   ```
5. **Append to TRACKING.md**:
   ```markdown
   ### Round <fix_round>
   **Verify**: FAIL — manual criteria failed: <list>. Fix round <N> initiated.
   ```
6. Suggest `/ca:plan` (or `/ca:next`) for fix planning. **Stop immediately.**

**If NO `manual` row has `result: fail`** (all pass or skipped), proceed to step 3f.

#### 3f. All-pass + open ISSUES check

Even when all defined criteria (auto + manual) PASS, check for **open issues** from either of two sources:

1. **Pre-existing `rounds/<fix_round>/ISSUES.md`** with one or more unchecked entries (e.g., a line matching `^- \[ \]` regex, or any non-empty `## Open Issues` / `## Newly Discovered Problems` section). This represents issues recorded earlier in the current round (e.g., the verifier wrote them in a prior verify within the same round, or another process recorded them).
2. **Verifier(s) reported newly-discovered problems** in the current run, beyond the defined criteria (problems surfaced in the "newly-discovered problems" section of the verifier report).

**If either source has open issues**:
1. **Write ISSUES.md** to the discovering round: `.ca/workflows/<active_id>/rounds/<fix_round>/ISSUES.md`. If this file already exists, ensure it includes both the pre-existing entries (unchanged) and any newly-reported problems (appended). If it does not exist (only verifier-reported), create it:
   ```markdown
   # Issues (Round <fix_round>)

   ## Newly Discovered Problems
   <list of problems found by verifier beyond defined criteria>
   ```
2. **Append new VERIFY.csv criteria** for any discovered problem that is also a new acceptance condition:
   ```
   node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-csv.js add-criterion \
     --file .ca/workflows/<active_id>/VERIFY.csv \
     --description "<problem description>" \
     --type test|self_check --method auto|manual
   ```
   Each appended criterion gets a new append-only id. This ensures it is re-verified in future rounds.
3. **Enter fix round**: Set N = fix_round + 1. Update STATUS.md:
   ```
   node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js update --project-root <project-root> --workflow-id <active_id> fix_round=<N> plan_completed=false plan_confirmed=false execute_completed=false verify_completed=false current_step=verify "status_note=All defined criteria passed but discovered problems (round <fix_round>). Fix round <N> initiated."
   ```
4. **Write VERIFY-REPORT.md** to `.ca/workflows/<active_id>/rounds/<fix_round>/VERIFY-REPORT.md` (if not already written).
5. **Append to TRACKING.md**:
   ```markdown
   ### Round <fix_round>
   **Verify**: PASS (defined criteria) but discovered problems: <list>. Fix round <N> initiated.
   ```
6. Report to user and suggest `/ca:plan` (or `/ca:next`). **Stop immediately.**

**If no newly-discovered problems**: proceed to step 4.

### 4. Present verification report

Mark "Present report & acceptance" as `in_progress`.

Display the report with auto and manual sections:

```
## Verification Report

### Auto Results
| # | ID | Type | Criterion | Status | Evidence |
|---|-----|------|-----------|--------|----------|
| 1 | v1 | self_check | ... | PASS/FAIL | ... |

### Manual Results
| # | ID | Criterion | Status | User Confirmation |
|---|-----|-----------|--------|-------------------|
| 1 | v2 | ... | PASS/FAIL | ... |

### Overall: PASS/FAIL
```

**CRITICAL — Verify write boundary (Reminder)**: Even at the final acceptance step, you MUST NOT modify any source code or project files, write fix plans, or call other skills. If the user rejects, record the issues and direct to `/ca:plan`. Do NOT attempt to fix anything.

### 5. MANDATORY CONFIRMATION — User Acceptance

**CRITICAL — Guard**: This step MUST only be reached when ALL auto criteria are PASS and ALL manual criteria are PASS (or were skipped per the guards in 3e), AND no open ISSUES exist from step 3f. If any criterion was FAIL or open ISSUES remain, the flow should have stopped earlier. Do NOT present acceptance options when failures or open issues exist.

If `batch_mode: true` OR (`auto_fix_mode: true` AND all manual rows are `pass`): skip user acceptance (all criteria passed = accepted) and proceed directly to step 6 (Update STATUS.md).

Use `AskUserQuestion` with:
- header: "[V.Results]"
- question: "Do you accept these results?"
- options:
  - "Accept" — "Results are satisfactory"
  - "Reject" — "Results need work"

- If the user **cancels and communicates directly**: Treat as Reject. Record feedback in VERIFY-REPORT.md, suggest `/ca:plan`. **Stop immediately.**
- If **Reject**:
  1. Ask what's wrong.
  1b. **Clean up tasks**: Call `TaskList` and mark ALL remaining tasks (pending or in_progress) as `deleted` using `TaskUpdate`.
  2. **Write VERIFY-REPORT.md**: Write to `.ca/workflows/<active_id>/rounds/<fix_round>/VERIFY-REPORT.md`.
  3. **Write ISSUES.md**: Write `.ca/workflows/<active_id>/rounds/<fix_round>/ISSUES.md` (the DISCOVERING round — current `fix_round`, NOT `fix_round+1`):
     ```markdown
     # Issues (Round <fix_round>)

     ## From User Feedback
     <user's rejection feedback>

     ## From Verification Report
     <any failed criteria from the report above, if applicable>
     ```
  4. **Determine next fix round**: Set N = fix_round + 1.
  5. **Update STATUS.md**: CRITICAL — Use `ca-status.js update` to ensure ALL fields are correctly reset. Run:
     ```
     node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js update --project-root <project-root> --workflow-id <active_id> fix_round=<N> plan_completed=false plan_confirmed=false execute_completed=false verify_completed=false current_step=verify "status_note=User rejected results (round <fix_round>): <brief feedback>. Ready for fix planning."
     ```
     Do NOT use Write or Edit tools to update STATUS.md.
  6. **Append to TRACKING.md**:
     ```markdown
     ### Round <fix_round>
     **Verify**: REJECTED by user — <brief feedback>. Fix round <N> initiated.
     ```
  7. Suggest `/ca:plan` (or `/ca:next`) for fix planning.
  8. **Stop immediately.** Do NOT fix, investigate, or modify code.
- If **Accept**: Proceed to step 6.

### 6. Update STATUS.md

Mark "Present report & acceptance" as `completed`.

Set `verify_completed: true`, `current_step: verify`.

If `auto_fix_mode: true` in STATUS.md: also update STATUS.md to set `auto_fix_mode=false` (clear the flag since verification passed).

Also set `status_note`, e.g.: "Verification passed. Ready for finish."

**Append to TRACKING.md**:
```markdown
### Round <fix_round>
**Verify**: PASS — all criteria passed, accepted. Workflow verify complete.
```

Tell the user verification is complete. Suggest next steps:
- `/ca:finish` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
