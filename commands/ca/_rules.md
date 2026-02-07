# CA Command Rules

## UI Rule

Before calling `AskUserQuestion`, always output structured content first (summary, list, checkpoint, etc.) so the user has sufficient context visible above the option picker.

## Todo Independence Rule

Users may invoke `/ca:todo` at any point during a workflow (discuss, research, plan, execute, verify). When this happens:
- Treat it as an independent command — process the todo addition, then resume the current workflow where you left off.
- Do NOT incorporate the todo content into the current requirement, plan, or discussion.
- Do NOT let the todo interrupt or alter the ongoing workflow state.
