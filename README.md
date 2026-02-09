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

This syncs slash commands to `~/.claude/commands/ca/`, agents to `~/.claude/agents/`, references to `~/.claude/ca/references/`, and registers the statusline hook. Stale files removed from source are automatically cleaned up during install.

## Uninstall

```bash
npx claude-agent --uninstall
```

Or from source:

```bash
npm run uninstall-ca
```

Removes commands, agents, and hooks from `~/.claude/`. Project `.ca/` directories and `~/.claude/ca/` config are preserved.

## Workflow

Two workflow modes are available:

**Full workflow** — for requirements that need discussion:

```
/ca:new → /ca:discuss → /ca:plan → /ca:execute → /ca:verify
```

**Quick workflow** — for clear, simple changes:

```
/ca:quick → /ca:plan → /ca:execute → /ca:verify
```

Use `/ca:next` at any point to automatically detect and run the next step.

### 1. New Requirement — `/ca:new [description]`

Creates a `.ca/` directory in your project for workflow state. Collects an initial requirement brief. On first run, auto-configures language settings if no global config exists. Warns if there is an unfinished workflow.

### 2. Discuss — `/ca:discuss`

Starts with automated 4-dimension research (Stack, Features, Architecture, Pitfalls) using parallel researcher agents, then clarifies your requirements through focused Q&A (one question at a time). Produces a requirement summary that you must confirm before moving on.

### 3. Plan — `/ca:plan`

For quick workflows, performs automated research first. Clarifies any uncertain items before drafting. Proposes an implementation plan with **triple confirmation** and backtracking:

1. **Requirement understanding** — "I understand you want X, correct?"
2. **Approach and method** — "I'll modify these files using this approach, agreed?"
3. **Expected results** — "The end result will be X, is that what you want?"

If changes at a later step affect earlier confirmations, the system backtracks and re-confirms affected steps. Success criteria are tagged `[auto]` or `[manual]` for verification.

### 4. Execute — `/ca:execute`

Runs the confirmed plan using isolated executor agents. Implementation steps use ordered/unordered list structure to express execution order — ordered items run sequentially, unordered items run in parallel. Only proceeds if the plan has been triple-confirmed. Returns an execution summary.

### 5. Verify — `/ca:verify`

Auto criteria are verified by independent verifier agents (optionally in parallel). If auto verification fails, automatically retries via plan → execute → verify cycle (max 3 times). Manual criteria are confirmed with you one at a time. After acceptance, optionally creates a git commit (message confirmed by you). Archives the workflow cycle to `.ca/history/`.

### Quick Mode — `/ca:quick [description]`

Skips the discuss phase. Creates a brief and goes straight to planning (with automated research). Best for small, well-understood changes.

## Other Commands

| Command | Description |
|---------|-------------|
| `/ca:quick [desc]` | Start a quick workflow (skip discuss) |
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
| `auto_proceed_to_plan` | Skip research confirmation in discuss, go straight to plan |
| `auto_proceed_to_verify` | Skip manual verify trigger after execution |
| `max_concurrency` | Max parallel agents in execute/verify (default: `4`) |
| `track_ca_files` | Version control for CA files: `none` (default), `all`, `.ca/`, or `.claude/rules/ca*` |

Per-agent model overrides (e.g., `ca-verifier_model: opus`) are also supported.

Use `/ca:settings` to configure.

## Project Structure

```
~/.claude/
  ca/
    config.md                    # Global config (language, model, concurrency, auto-proceed)
    version                      # Installed version number
    references/                  # Reference files (model-profiles.md, etc.)
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
| `ca-executor` | Implements the plan (parallel for independent steps) | Code edits cause context bloat |
| `ca-verifier` | Independent verification (supports auto/manual, parallel mode) | Fresh context avoids confirmation bias |

## Statusline

CA installs a status bar hook that displays:
- Current model name
- "ca" + version number
- Context window usage bar

## License

MIT
