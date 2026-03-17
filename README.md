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

This syncs slash commands to `~/.claude/commands/ca/`, agents to `~/.claude/agents/`, scripts to `~/.claude/ca/scripts/`, references to `~/.claude/ca/references/`, and registers the statusline hook. Stale files removed from source are automatically cleaned up during install.

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
/ca:new → /ca:discuss → /ca:plan → /ca:execute → /ca:verify → /ca:finish
```

**Quick workflow** — for clear, simple changes:

```
/ca:quick → /ca:plan → /ca:execute → /ca:verify → /ca:finish
```

Each workflow optionally creates a dedicated git branch (`ca/<workflow-id>`) for isolated development.

Use `/ca:next` at any point to automatically detect and run the next step.

**Multi-workflow** — plan multiple requirements, then batch execute:

```
/ca:new → /ca:discuss → /ca:plan   (repeat for each requirement)
/ca:switch                          (switch between workflows)
/ca:batch                           (batch execute all confirmed plans)
```

### Branch Management

When `use_branches` is enabled (default), each workflow operates on a dedicated branch:

- **Branch creation** — `/ca:new` or `/ca:quick` creates a `ca/<workflow-id>` branch from the current base branch
- **Auto-commit** — after execution, changes are automatically committed to the workflow branch
- **Finish** — `/ca:finish` squash-merges (or regular merge, based on `merge_strategy`) the workflow branch back to the base branch
- **Cleanup** — the workflow branch is automatically deleted after merge when `auto_delete_branch` is true (default)

This keeps your main branch clean and gives each requirement its own isolated history.

### 1. New Requirement — `/ca:new [description]`

Creates a workflow in `.ca/workflows/<id>/`. If an unfinished workflow exists, offers to keep it alongside the new one, archive it, or continue it. Collects an initial requirement brief. On first run, auto-configures language settings if no global config exists.

### 2. Discuss — `/ca:discuss`

Starts with automated 4-dimension research (Stack, Features, Architecture, Pitfalls) using parallel researcher agents, then clarifies your requirements through focused Q&A (one question at a time). Produces a requirement summary that you must confirm before moving on.

### 3. Plan — `/ca:plan`

For quick workflows, assesses requirement complexity — simple requirements can skip research, complex ones get automated research. Clarifies any uncertain items before drafting. Proposes an implementation plan with **triple confirmation** and backtracking:

1. **Requirement understanding** — "I understand you want X, correct?"
2. **Approach and method** — "I'll modify these files using this approach, agreed?"
3. **Expected results** — "The end result will be X, is that what you want?"

If changes at a later step affect earlier confirmations, the system backtracks and re-confirms affected steps. Success criteria are tagged `[auto]` or `[manual]` for verification.

### 4. Execute — `/ca:execute`

Runs the confirmed plan using isolated executor agents. Implementation steps use ordered/unordered list structure to express execution order — ordered items run sequentially, unordered items run in parallel. Only proceeds if the plan has been triple-confirmed. Returns an execution summary. When branch management is enabled, changes are auto-committed to the workflow branch after execution.

### 5. Verify — `/ca:verify`

Auto criteria are verified by independent verifier agents (optionally in parallel). If auto verification fails, asks you whether to auto-fix and retry (max 3 times) or stop for manual review. In batch mode, verification runs fully automated — skips manual criteria, user acceptance, and gitignore check; auto-commits on success; fails immediately without retry on failure. Manual criteria are confirmed with you one at a time. After acceptance, optionally creates a git commit (message confirmed by you). Archives the workflow cycle to `.ca/history/`.

### 6. Finish — `/ca:finish`

Merges the workflow branch back to the base branch and cleans up. When `use_branches` is enabled, squash-merges (or regular merge based on `merge_strategy`) the `ca/<workflow-id>` branch into the base branch, then deletes the workflow branch if `auto_delete_branch` is true.

### Quick Mode — `/ca:quick [description]`

Skips the discuss phase. Creates a brief and goes straight to planning. For simple requirements, the system offers to skip the 4-dimension research; for complex ones, research runs automatically. Best for small, well-understood changes.

## Other Commands

| Command | Description |
|---------|-------------|
| `/ca:quick [desc]` | Start a quick workflow (skip discuss) |
| `/ca:next` | Auto-detect and run the next workflow step |
| `/ca:map` | Scan and record project structure |
| `/ca:settings` | Configure language, model, and auto-proceed settings |
| `/ca:status` | Show current workflow state |
| `/ca:switch` | Switch active workflow |
| `/ca:list` | List all workflows with status summary |
| `/ca:batch` | Batch execute all plan-confirmed workflows |
| `/ca:remember <info>` | Save to persistent context (project or global) |
| `/ca:context` | Show loaded context in current session |
| `/ca:forget <info>` | Remove from persistent context |
| `/ca:todo <item>` | Add a todo item |
| `/ca:todos` | List all todos |
| `/ca:errors` | Show and manage error lessons |
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
| `use_branches` | Git branch per workflow: `true` (default) or `false` |
| `merge_strategy` | How to merge workflow branch at finish: `squash` (default) or `merge` |
| `auto_delete_branch` | Auto-delete workflow branch after merge: `true` (default) or `false` |

Per-agent model overrides (e.g., `ca-verifier_model: opus`) are also supported.

Use `/ca:settings` to configure.

## Project Structure

```
~/.claude/
  ca/
    config.md                    # Global config (language, model, concurrency, auto-proceed)
    version                      # Installed version number
    scripts/                     # Node.js scripts for deterministic operations
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
  active.md                      # Currently active workflow ID
  workflows/
    <workflow-id>/
      STATUS.md                  # Workflow state
      BRIEF.md                   # Initial requirement brief
      REQUIREMENT.md             # Finalized requirement from /ca:discuss
      PLAN.md                    # Confirmed plan from /ca:plan
      SUMMARY.md                 # Execution summary from /ca:execute
      CRITERIA.md                # Success criteria from /ca:plan
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

## Testing

### Prerequisites

- `tmux` — used to run Claude in a detached terminal session
- `claude` CLI — must support `--model` and `--dangerously-skip-permissions` flags
- `jq` — used for JSON parsing in helper scripts
- `node` — used for CA install and status scripts

### Run all tests

```bash
npm test
```

### Run a single phase

```bash
npm run test:phase -- 1
```

Replace `1` with `2` or `3` to run a specific phase.

### Test architecture

Tests are organized into three phases under `tests/phases/`:

| Phase | Script | Description |
|-------|--------|-------------|
| 1 | `phase1_quick.sh` | Quick workflow: `/ca:quick` → `/ca:plan` → `/ca:execute` → `/ca:verify` → `/ca:finish` |
| 2 | `phase2_standard.sh` | Standard workflow: `/ca:new` → `/ca:discuss` → `/ca:plan` → `/ca:execute` → `/ca:verify` → `/ca:finish` |
| 3 | `phase3_helpers.sh` | Helper commands: `/ca:todo`, `/ca:todos`, `/ca:map`, `/ca:status`, `/ca:list` |

Shared infrastructure lives in `tests/e2e_common.sh` (setup, tmux helpers, assertions, result recording). Each phase runs in a fully isolated temp directory with its own `HOME` override so tests never affect your real Claude config.

## License

MIT
