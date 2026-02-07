# Why CA Exists

## The Problem

AI coding assistants are powerful but have a fundamental tendency: they act first, ask later. Give Claude Code a task and it will immediately start writing code, making architectural decisions, and "improving" things you never asked for. By the time you see the result, you're left reverse-engineering what happened and why.

This creates several failure modes:

- **Misunderstood requirements** — The AI builds the wrong thing confidently. You waste a round-trip correcting it.
- **Unauthorized decisions** — It picks an approach you wouldn't have chosen. Refactoring costs more than starting over.
- **Scope creep** — It "helpfully" refactors nearby code, adds error handling you didn't need, or restructures files to match its aesthetic preferences.
- **Confirmation bias** — When the same context that wrote the code also verifies it, problems get rationalized away.

These aren't bugs in the model. They're a workflow problem. The default interaction pattern — "here's a task, go do it" — gives the AI maximum autonomy and the user minimum oversight.

## The Philosophy

CA inverts this dynamic. The user controls every decision point. The AI proposes; the user disposes.

### You confirm, then it acts

Nothing gets written to disk until you've explicitly approved:
- What the requirement actually is
- How it will be implemented
- What the end result should look like

This is the triple confirmation in `/ca:plan` — the system's core mechanism. It exists because the gap between "what you said" and "what the AI understood" is where most waste happens. Closing that gap before any code is written is cheaper than fixing it after.

### Each step is a checkpoint

The workflow is sequential and gated:

```
discuss → research → plan → execute → verify
```

You can't skip ahead. You can't execute without a confirmed plan. You can't verify without an execution. Each step produces a concrete artifact (REQUIREMENT.md, PLAN.md, etc.) that serves as a contract between you and the AI.

If something goes wrong, `/ca:fix` lets you roll back to any step. The artifacts from previous attempts are preserved for reference.

### Isolation prevents contamination

Research, execution, and verification each run in separate agent contexts. This isn't just an optimization — it's a design choice:

- The **researcher** gathers facts without proposing solutions, so findings aren't biased toward a particular approach.
- The **executor** works from a written plan in a clean context, so it follows instructions rather than "remembering" the discussion and improvising.
- The **verifier** checks results in a fresh context, so it can't rationalize problems it participated in creating.

### The user is the architect

The AI handles the labor-intensive parts: scanning codebases, writing boilerplate, checking for regressions. But the decisions — what to build, how to build it, whether it's done — belong to you.

This is a deliberate trade-off. CA is slower than letting Claude run free. You'll answer more questions and confirm more prompts. The payoff is that what gets built is what you actually wanted, and you understood every step of how it got there.

## Design Principles

1. **No automatic progression** — Each command ends by telling you what's available next. It never silently moves to the next step.
2. **Artifacts over memory** — Everything important is written to files in `.ca/`. If context is lost, the artifacts remain.
3. **Explicit over implicit** — If the AI needs to make a choice, it asks. If something is ambiguous, it clarifies. If a step fails, it reports rather than retries.
4. **Minimal footprint** — CA is just markdown files that instruct Claude Code how to behave. No runtime dependencies, no build step, no lock-in. Uninstall and everything is gone except your `.ca/` data.
5. **Reversibility** — Every step can be rolled back. Files are archived, not deleted. You can always get back to a known state.
