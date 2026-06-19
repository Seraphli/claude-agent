# TRACKING.md Format (per-workflow narrative)

Location: workflow root `TRACKING.md` — one per workflow, spans the whole lifecycle (does NOT go into rounds/). Structured; non-duplicative; stays scannable even at 20-30 fix rounds. Records what the rest of the flow does NOT capture — especially DECISIONS reached in conversation with the user during grilling (why X was chosen, what was rejected, user preferences), plus a NECESSARY per-round summary.

Distinct from ADR: TRACKING.md is per-WF (archived with the workflow); ADR is cross-WF (project-level, permanent).

## Structure

```md
# Tracking — {workflow-id}

## Decisions
- [phase] {decision} — chose {X} over {Y} because {reason}. (user: {preference})

## Rounds
### Round 0
- Plan: {1-line}. Execute: {plan-vs-execution divergence, if any}. Verify: {result}.
### Round 1 (fix)
- ...
```

Append as the workflow progresses; do not restate content already in PLAN.md/SUMMARY.md/VERIFY-REPORT.md.
