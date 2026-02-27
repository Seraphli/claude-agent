# /ca:verify — Verify Results

Read config by running: `node ~/.claude/ca/scripts/ca-config.js --project-root <project-root>`. Parse the JSON output to get all config values.

## Prerequisites

1. Run: `node ~/.claude/ca/scripts/ca-status.js read --project-root <project-root>`. Parse the JSON output.
   - If output contains `"error"`, tell the user to run `/ca:new` first and stop.
2. Verify `execute_completed: true` from the parsed JSON. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

**IMPORTANT — AskUserQuestion Fallback**: For ALL `AskUserQuestion` calls in this command: if the user does not select any predefined option (response contains `"__chat"="true"`), you MUST stop the current flow, acknowledge the user's input, and respond appropriately. `"__chat"` is a sentinel value for free-input mode, NOT a valid answer — never treat it as selecting any option. Do NOT ignore unselected options and continue with default behavior.

**CRITICAL — Verify is READ-ONLY**: Throughout the ENTIRE verify command lifecycle, you MUST NEVER:
- Modify any source code or project files
- Research or analyze how to fix failures
- Investigate root causes by reading source code
- Write fix plans or solutions
- Call other skills (ca:plan, ca:execute, etc.)

This applies regardless of how the user communicates — whether through AskUserQuestion options, canceling option selection and typing directly, or any other interaction pattern. If the user raises issues, reports problems, or asks questions at ANY point during verification, respond with information from the verification context only, then guide them to use `/ca:fix`. Never start fixing or investigating.

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

Read `model_profile` and `ca-verifier_model` from the config JSON already loaded.
Resolve model: `ca-verifier_model` override → `model_profile` via `~/.claude/ca/references/model-profiles.md`. Pass to Task tool.

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
1. **Write VERIFY-REPORT.md**:
   - If `fix_round` > 0: write to `.ca/workflows/<active_id>/rounds/<N>/VERIFY-REPORT.md`
   - If `fix_round` == 0: write to `.ca/workflows/<active_id>/VERIFY-REPORT.md`
   The report MUST contain:
   - Which criteria failed and what the failure details are
   - References to any verifier output/log files
   - Do NOT include fix plans, suggestions, or solutions — only record the problems
2. Report the failures to the user (show the report summary).
3. Suggest the user run `/ca:fix` to go back to a previous step and fix the issues.
4. **Stop immediately.**

**CRITICAL — No Fixing in Verify**: The verify command MUST NEVER:
- Modify source code or project files
- Research or analyze how to fix failures
- Investigate root causes by reading source code
- Write fix plans or solutions in the report
- Reset STATUS.md or modify PLAN.md
- Call other skills (ca:plan, ca:execute, etc.)
- Re-run tests that already have logged output

If the user raises issues or asks about failures, respond with report information only, then guide to `/ca:fix`. Never start fixing or investigating within the verify context.

#### 3e. Manual verification

If `batch_mode: true` in STATUS.md: skip manual verification entirely and proceed to step 4.

Present all `[manual]` criteria to the user one at a time. For each:
- Describe what needs to be verified
- Use `AskUserQuestion` to ask the user to confirm PASS or FAIL
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

### 5. MANDATORY CONFIRMATION — User Acceptance

If `batch_mode: true` in STATUS.md: skip user acceptance (auto criteria all passed = accepted) and proceed directly to step 6 (Update STATUS.md).

Use `AskUserQuestion` with:
- header: "Results"
- question: "Do you accept these results?"
- options:
  - "Accept" — "Results are satisfactory"
  - "Reject" — "Results need work"

- If the user **cancels and communicates directly**: Treat as Reject. Record feedback in VERIFY-REPORT.md, suggest `/ca:fix`. **Stop immediately.**
- If **Reject**: Ask what's wrong, record in VERIFY-REPORT.md (fix-round path if applicable), suggest `/ca:fix`. No fixing or investigating.
- If **Accept**: Proceed to step 6.

### 6. Update STATUS.md

Set `verify_completed: true`, `current_step: verify`.

Tell the user verification is complete. Suggest next steps:
- `/ca:finish` (or `/ca:next`)
- `/clear` to free context

If `show_tg_commands: true`, also show `/ca_xxx` format. Built-in commands (`/clear`) excluded.

**Do NOT auto-proceed.**
