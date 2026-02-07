# CA Command Rules

## UI Rule

Before calling `AskUserQuestion`, always output structured content first (summary, list, checkpoint, etc.) so the user has sufficient context visible above the option picker.

In the message immediately before an `AskUserQuestion` call, always end with a horizontal rule (`---`) as the last line. This prevents the option picker from obscuring the last visible line of content.

## Discussion Completeness Rule

When asking clarifying questions one at a time during the discuss phase:
- If the user indicates they don't understand the question, you MUST explain or rephrase the current question first before moving on.
- Do NOT skip to the next question when the user's response shows confusion, disagreement, or a request for clarification about the current question.
- Only proceed to the next question after the current one is clearly resolved.

## Error Recording Rule

When an agent makes a mistake during execution (wrong file, logic error, repeated mistake, etc.), it must record the error:
- **Project-level**: Append to `.claude/rules/ca-errors.md` for project-specific lessons.
- **Global-level**: Append to `~/.claude/rules/ca-errors.md` for cross-project lessons.

Format each entry as:
```
- [YYYY-MM-DD] <brief description of the error and what was learned>
```

## Todo Independence Rule

Users may invoke `/ca:todo` at any point during a workflow (discuss, research, plan, execute, verify). When this happens:
- Treat it as an independent command — process the todo addition, then resume the current workflow where you left off.
- Do NOT incorporate the todo content into the current requirement, plan, or discussion.
- Do NOT let the todo interrupt or alter the ongoing workflow state.

## Map-First File Lookup Rule

When searching for project-related files, agents must follow this priority:
1. **First**, check `.ca/map.md` (if it exists) for the file location or relevant section.
2. **Only if** the map does not contain the needed information, fall back to Glob/Grep search.

This reduces unnecessary searches and ensures agents leverage the existing codebase map.
