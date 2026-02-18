# /ca:verify — Verify Results

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. These are needed for runtime settings (model_profile, auto_proceed_*, per-agent model overrides).

## Prerequisites

1. Read `.ca/active.md` to get the active workflow ID. If it doesn't exist, tell the user to run `/ca:new` first and stop.
2. Check `.ca/workflows/<active_id>/STATUS.md` exists. If not, tell the user to run `/ca:new` first and stop.
3. Read `.ca/workflows/<active_id>/STATUS.md` and verify `execute_completed: true`. If not, tell the user to run `/ca:execute` first. **Stop immediately.**

## Behavior

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

Read the model configuration from config (global then workspace override):
1. Check for per-agent override: `ca-verifier_model` in config. If set, use that model.
2. Otherwise, read `model_profile` from config (default: `balanced`). Read `~/.claude/ca/references/model-profiles.md` and look up the model for `ca-verifier` in the corresponding profile column.
3. The resolved model will be passed to the Task tool.

### 3. Execute auto verification

#### 3a. Parse auto criteria structure

Read the `[auto]` section from CRITERIA.md. Check the list structure:
- If **unordered list** with multiple items that can be split: go to 3c (parallel verification).
- Otherwise: go to 3b (single verifier).

#### 3b. Single verifier

Launch a single `ca-verifier` agent with all `[auto]` criteria. The agent verifies each criterion and returns a report.

#### 3c. Parallel verification (optional)

Read `max_concurrency` from config (default: `4`). If the number of parallel groups exceeds `max_concurrency`, split into batches of `max_concurrency` size and execute batches sequentially. For each batch (or all groups if within limit), launch multiple `ca-verifier` agents **in the same message**, each handling a subset of `[auto]` criteria (based on the unordered list grouping). Each agent receives:
- Its assigned criteria
- All context files (REQUIREMENT.md/BRIEF.md, PLAN.md, SUMMARY.md)
- The project root path
- A unique output file path: `VERIFY-verifier-{N}.md`

Wait for all agents to complete, then merge reports.

#### 3d. Handle auto results

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
- Modify any source code or project files
- Research or analyze how to fix failures
- Investigate root causes by reading source code
- Write fix plans or solutions in the report
- Reset STATUS.md or modify PLAN.md
- Call other skills (ca:plan, ca:execute, etc.)
- Re-run tests that already have logged output

If the user raises issues or asks questions about failures, respond with information from the report only, then guide them to use `/ca:fix`. Never start fixing or investigating within the verify context.

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

- If the user **cancels the selection and communicates directly** (e.g., raises new issues, asks questions, or describes problems in chat instead of clicking Accept/Reject): Treat this the same as a Reject. Do NOT investigate, analyze, or fix anything. Record the user's feedback in VERIFY-REPORT.md, then suggest running `/ca:fix`. **Stop immediately.**
- If **Reject**: Ask what's wrong to understand the issue, record it in VERIFY-REPORT.md (if `fix_round` > 0: `.ca/workflows/<active_id>/rounds/<N>/VERIFY-REPORT.md`, else: `.ca/workflows/<active_id>/VERIFY-REPORT.md`), then suggest running `/ca:fix` to go back to an earlier step. Do NOT attempt any fix, investigation, or modification — only record and guide.
- If **Accept**: Proceed to step 6.

### 6. Update STATUS.md

Set `verify_completed: true`, `current_step: verify`.

Tell the user verification is complete. Suggest next steps:
- Run `/ca:finish` to wrap up the workflow (or use `/ca:next`)
- Suggest using `/clear` before proceeding to free up context

**Do NOT proceed to finish automatically.**
