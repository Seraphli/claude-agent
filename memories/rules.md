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

The `ca-errors.md` files serve as **persistent error memory** for agents. They are auto-loaded by Claude Code's rules system, so agents automatically learn from past mistakes and avoid repeating them. There are two levels:
- **Project-level** (`.claude/rules/ca-errors.md`): Lessons specific to this project (e.g., project conventions, architecture patterns).
- **Global-level** (`~/.claude/rules/ca-errors.md`): Lessons that apply across all projects (e.g., general coding mistakes, tool usage errors).

### When to record errors

Agents MUST record errors in the following situations:
- Making a mistake during execution (wrong file, logic error, incorrect approach, etc.)
- Repeating a previously recorded mistake
- **When the user expresses frustration or anger** — this is a strong signal that something went wrong. Immediately identify the cause, apologize, fix the issue, and record the lesson.
- When the user corrects the agent's behavior or output

### How to record

Append to the appropriate `ca-errors.md` file:

Format each entry as:
```
- [YYYY-MM-DD] <brief description of the error and what was learned>
```

- Use **project-level** for project-specific lessons.
- Use **global-level** for cross-project lessons.
- Keep entries concise but actionable — future agents should understand what to avoid.

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

## Todo File Safety Rule

When reading or modifying `.ca/todos.md`:
- **ONLY** use `Read` tool to read the file
- **ONLY** use `Write` or `Edit` tool to modify the file
- **NEVER** use `Bash` commands (cat, echo, sed, awk, etc.) to write to todos.md
- This prevents accidental data loss from overwriting the file without reading it first
