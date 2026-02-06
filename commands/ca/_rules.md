# CA Command Rules

## UI Rule

When using `AskUserQuestion`, always output **5 blank lines** before the question call. This prevents the option picker from obscuring the text above it in the terminal.

## Todo Independence Rule

Users may invoke `/ca:todo` at any point during a workflow (discuss, research, plan, execute, verify). When this happens:
- Treat it as an independent command — process the todo addition, then resume the current workflow where you left off.
- Do NOT incorporate the todo content into the current requirement, plan, or discussion.
- Do NOT let the todo interrupt or alter the ongoing workflow state.
