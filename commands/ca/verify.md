# /ca:verify — Verify Results

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca-status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `execute_completed: true` from the parsed JSON. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

**CRITICAL — Verify is READ-ONLY**: Throughout the ENTIRE verify command lifecycle, you MUST NEVER:
- Modify any source code or project files
- Write fix plans, solutions, or suggestions for how to fix failures
- Call other skills (ca:plan, ca:execute, etc.)

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

### 2. Resolve model for ca-verifier

Read `ca-verifier_model` from the config JSON already loaded. This is the already-resolved model name (opus/sonnet/haiku). Pass to Task tool.

### 3. Execute auto verification

#### 3a. Parse auto criteria structure

Read the `[auto]` section from CRITERIA.md. Check the list structure:
- If **unordered list** with multiple items that can be split: go to 3c (parallel verification).
- Otherwise: go to 3b (single verifier).

#### 3b. Single verifier

Launch a single `ca-verifier` agent with all `[auto]` criteria. The agent verifies each criterion and returns a report.

#### 3c. Parallel verification (optional)

Read `max_concurrency` from the config JSON already loaded. If the number of parallel groups exceeds `max_concurrency`, split into batches of `max_concurrency` size and execute batches sequentially. For each batch (or all groups if within limit), launch multiple `ca-verifier` agents **in the same message**, each handling a subset of `[auto]` criteria (based on the unordered list grouping). Each agent receives:
- Its assigned criteria
- All context files (REQUIREMENT.md/BRIEF.md, PLAN.md, SUMMARY.md)
- The project root path
- A unique output file path: `VERIFY-verifier-{N}.md`

Wait for all agents to complete, then merge reports.

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
5. **Update STATUS.md**:
   - `fix_round: <N>`
   - `plan_completed: false`
   - `plan_confirmed: false`
   - `execute_completed: false`
   - `verify_completed: false`
   - `current_step: verify`
   - `status_note: Verification failed (round N): <brief failure summary>. Ready for fix planning.`
6. Report the failures to the user (show the report summary).
7. Suggest the user run `/ca:plan` (or `/ca:next`) to plan the fix.
8. **Stop immediately.**

**CRITICAL — No Fixing in Verify**: The verify command MUST NEVER:
- Modify source code or project files
- Write fix plans, solutions, or suggestions in the report
- Reset STATUS.md or modify PLAN.md
- Call other skills (ca:plan, ca:execute, etc.)
- Re-run tests that already have logged output

You CAN read source code to understand the current state and explain issues to the user. The prohibition is on modifying code and proposing fixes, not on reading and understanding.

If the user raises issues or asks about failures, you may read code and explain the situation, but guide to `/ca:plan` for actual fixes. Never modify code within the verify context.

#### 3e. Manual verification

If `batch_mode: true` in STATUS.md: skip manual verification entirely and proceed to step 4.

Present all `[manual]` criteria to the user one at a time. For each:
- Describe what needs to be verified
- Use `AskUserQuestion` to ask the user to confirm PASS or FAIL:
  - **CRITICAL**: header MUST be exactly `"Manual"`
  - question: describe the criterion and ask for PASS/FAIL confirmation
  - options: "Pass" / "Fail"
- Record the result

After all manual criteria are verified, proceed to step 4.

### 4. Present verification report

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

If `batch_mode: true` in STATUS.md: skip user acceptance (auto criteria all passed = accepted) and proceed directly to step 6 (Update STATUS.md).

Use `AskUserQuestion` with:
- header: "Results"
- question: "Do you accept these results?"
- options:
  - "Accept" — "Results are satisfactory"
  - "Reject" — "Results need work"

- If the user **cancels and communicates directly**: Treat as Reject. Record feedback in VERIFY-REPORT.md, suggest `/ca:plan`. **Stop immediately.**
- If **Reject**: Ask what's wrong, record in VERIFY-REPORT.md (fix-round path if applicable), suggest `/ca:plan`. No fixing or investigating.
- If **Accept**: Proceed to step 6.

### 6. Update STATUS.md

Set `verify_completed: true`, `current_step: verify`.

Also set `status_note`, e.g.: "Verification passed. Ready for finish."

Tell the user verification is complete. Suggest next steps:
- `/ca:finish` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
