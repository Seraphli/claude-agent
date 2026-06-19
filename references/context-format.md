# CONTEXT.md Format (CA terminology glossary)

Location: `.ca/docs/CONTEXT.md` — project-level, shared across all workflows (and, in multi-repo workflows, across all repos; it lives only at the orchestration location's `.ca/docs/`). Pure glossary — NO implementation details, no spec, no scratch pad.

## Structure

```md
# {Project} Context

{One or two sentences: what this context is and why it exists.}

## Language

**Term**:
{One or two sentence definition — what it IS, not what it does.}
_Avoid_: alias1, alias2

**AnotherTerm**:
...

## Example dialogue

{A short dev/domain-expert exchange demonstrating how the terms interact and where the boundaries are.}
```

## Rules
- Be opinionated: one canonical term, list synonyms under `_Avoid_`.
- Tight definitions (≤2 sentences). Only project-specific terms (no general programming concepts).
- Group under subheadings when natural clusters emerge; a flat list is fine otherwise.
- **Write criteria:** only write/update an entry AFTER the user confirms the canonical term and its definition. A merely-recommended-but-unanswered question is NOT written.
- **On conflict:** update the affected entry and its `_Avoid_` list in place.
- Lazy creation: create the file when the first term is resolved.
