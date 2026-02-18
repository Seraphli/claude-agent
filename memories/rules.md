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

**Before recording, agents MUST get user confirmation:**
1. Present the proposed error entry to the user (show the exact text that would be recorded)
2. Use `AskUserQuestion` to ask: "Record this error lesson?" with options "Yes, record" / "No, skip" / "Revise"
3. If **Yes**: proceed to record
4. If **No**: skip recording entirely
5. If **Revise**: let the user modify the content, then record the revised version

Append to the appropriate `ca-errors.md` file:

Format each entry as:
```
- [YYYY-MM-DD] <brief description of the error and what was learned>
```

- Use **project-level** for project-specific lessons.
- Use **global-level** for cross-project lessons.
- Keep entries concise but actionable — future agents should understand what to avoid.

### When NOT to record errors

- **Verify failures**: When `ca-verifier` reports criterion failures during `/ca:verify`, these are normal workflow results (expected part of the verify→fix cycle). Agents MUST NOT record verify failures in `ca-errors.md`. Only record errors when the agent itself makes a mistake (wrong approach, logic error, incorrect behavior), NOT when verification correctly identifies that code doesn't meet criteria.

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

## Localization Rule

All structural output content MUST match the `interaction_language` setting from ca-settings:

- **Markdown headings** (`##`, `###`) in output to the user: translate to the target language
- **AskUserQuestion** `header`, `question`, and `options` text: use the target language
- **Table headers** in output: translate to the target language

**Exception**: Headings inside file templates (PLAN.md, CRITERIA.md, SUMMARY.md, etc.) MUST remain in English. These serve as structural keys for cross-command parsing. Only translate headings when displaying output directly to the user.

Examples (interaction_language: 中文):
- `## Research Findings` → `## 研究发现`
- `## Verification Report` → `## 验证报告`
- `## Execution Summary` → `## 执行摘要`
- `### Changes Made` → `### 变更内容`
- `### Success Criteria` → `### 成功标准`
- `### Expected Results` → `### 预期结果`
- AskUserQuestion header "Requirements" → "需求确认"
