# ADR Format (CA Architecture Decision Records)

Location: `.ca/docs/adr/NNNN-slug.md` — project-level, cross-workflow, permanent. Lazy creation; sequential numbering (scan `.ca/docs/adr/` for the highest NNNN, increment).

## Template

```md
# {Short title of the decision}

{1-3 sentences: context, what was decided, and why.}
```

Optional sections, only when they add value: `Status` frontmatter (proposed | accepted | deprecated | superseded by ADR-NNNN), `Considered Options`, `Consequences`.

## When to OFFER an ADR (plan asks the user; it does NOT auto-create)

All THREE must hold:
1. Hard to reverse — the cost of changing your mind later is meaningful.
2. Surprising without context — a future reader will wonder "why did they do it this way?"
3. A real trade-off — genuine alternatives existed and one was chosen for specific reasons.

If any is missing, do not offer.
