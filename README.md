# CA — Claude Agent

A user-controlled development workflow for Claude Code. Every step requires your explicit confirmation before proceeding.

## Install

```bash
npx claude-agent
```

Or install from source:

```bash
git clone https://github.com/Seraphli/claude-agent.git
cd claude-agent
npm run install-ca
```

This copies slash commands to `~/.claude/commands/ca/`, agents to `~/.claude/agents/`, and registers the statusline hook.

## Uninstall

```bash
npm run uninstall-ca
```

Removes commands, agents, and hooks from `~/.claude/`. Project `.ca/` directories and `~/.claude/ca/` config are preserved.

## Workflow

Two workflow modes are available:

**Full workflow** — for requirements that need discussion and research:

```
/ca:new → /ca:discuss → /ca:research → /ca:plan → /ca:execute → /ca:verify
```

**Quick workflow** — for clear, simple changes:

```
/ca:quick → /ca:plan → /ca:execute → /ca:verify
```

Use `/ca:next` at any point to automatically detect and run the next step.

### 1. New Requirement — `/ca:new [description]`

Creates a `.ca/` directory in your project for workflow state. Collects an initial requirement brief. On first run, auto-configures language settings if no global config exists. Warns if there is an unfinished workflow.

### 2. Discuss — `/ca:discuss`

Clarifies your requirements through focused Q&A (one question at a time), starting from the brief collected in `/ca:new`. Produces a requirement summary that you must confirm before moving on.

### 3. Research — `/ca:research` (optional)

Analyzes the codebase and optionally searches external resources. Uses an isolated agent to keep the main conversation clean. Findings require your confirmation.

### 4. Plan — `/ca:plan`

Proposes an implementation plan with **triple confirmation**:

1. **Requirement understanding** — "I understand you want X, correct?"
2. **Approach and method** — "I'll modify these files using this approach, agreed?"
3. **Expected results** — "The end result will be X, is that what you want?"

All three must pass before the plan is finalized.

### 5. Execute — `/ca:execute`

Runs the confirmed plan using an isolated executor agent. Only proceeds if the plan has been triple-confirmed. Returns an execution summary.

### 6. Verify — `/ca:verify`

An independent verifier agent checks every success criterion in a fresh context. After your acceptance, optionally creates a git commit (message confirmed by you). Archives the workflow cycle to `.ca/history/`.

### Quick Mode — `/ca:quick [description]`

Skips the discuss and research phases entirely. Creates a brief and goes straight to planning. Best for small, well-understood changes.

## Other Commands

| Command | Description |
|---------|-------------|
| `/ca:quick [desc]` | Start a quick workflow (skip discuss/research) |
| `/ca:next` | Auto-detect and run the next workflow step |
| `/ca:map` | Scan and record project structure |
| `/ca:settings` | Configure language, model, and auto-proceed settings |
| `/ca:status` | Show current workflow state |
| `/ca:fix [step]` | Roll back to a previous step |
| `/ca:remember <info>` | Save to persistent context (project or global) |
| `/ca:context` | Show loaded context in current session |
| `/ca:forget <info>` | Remove from persistent context |
| `/ca:todo <item>` | Add a todo item |
| `/ca:todos` | List all todos |
| `/ca:help` | Show command reference |

## Configuration

CA uses a dual-layer configuration system:

- **Global** (`~/.claude/ca/config.md`) — applies to all projects
- **Workspace** (`.ca/config.md`) — applies to current project, overrides global

Three language settings:

| Setting | Purpose |
|---------|---------|
| `interaction_language` | Language for conversations |
| `comment_language` | Language for code comments |
| `code_language` | Language for code strings (logs, errors, etc.) |

Additional settings:

| Setting | Purpose |
|---------|---------|
| `model_profile` | Agent model tier: `quality`, `balanced` (default), or `budget` |
| `auto_proceed_to_plan` | Skip research confirmation, go straight to plan |
| `auto_proceed_to_verify` | Skip manual verify trigger after execution |

Per-agent model overrides (e.g., `ca-verifier_model: opus`) are also supported.

Use `/ca:settings` to configure.

## Project Structure

```
~/.claude/
  ca/
    config.md                    # Global config (language, model, auto-proceed)
    version                      # Installed version number
  commands/ca/                   # Slash commands (installed by install-ca)
  agents/                        # Agent definitions (installed by install-ca)
  rules/
    ca-rules.md                  # Shared rules (auto-loaded)
    ca-settings.md               # Global language settings (auto-loaded)
    ca-context.md                # Global persistent context (auto-loaded)
    ca-errors.md                 # Global error lessons (auto-loaded)

.ca/                             # Created per-project by /ca:new or /ca:quick
  config.md                      # Workspace config (overrides global)
  todos.md                       # Todo list with archive
  map.md                         # Codebase structure map (/ca:map)
  current/
    STATUS.md                    # Workflow state
    BRIEF.md                     # Initial requirement brief
    REQUIREMENT.md               # Finalized requirement from /ca:discuss
    RESEARCH.md                  # Findings from /ca:research
    PLAN.md                      # Confirmed plan from /ca:plan
    SUMMARY.md                   # Execution summary from /ca:execute
    CRITERIA.md                  # Success criteria from /ca:plan
  history/
    0001-feature-slug/           # Archived workflow cycles

.claude/rules/                   # Project-level rules (auto-loaded)
  ca-settings.md                 # Project language settings
  ca-context.md                  # Project persistent context
  ca-errors.md                   # Project error lessons
```

## Agents

| Agent | Role | Why isolated |
|-------|------|-------------|
| `ca-researcher` | Deep codebase analysis | Research consumes large context |
| `ca-executor` | Implements the plan | Code edits cause context bloat |
| `ca-verifier` | Independent verification | Fresh context avoids confirmation bias |

## Statusline

CA installs a status bar hook that displays:
- Current model name
- "ca" + version number
- Context window usage bar

## License

MIT
