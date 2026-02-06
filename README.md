# CA — Claude Agent

A user-controlled development workflow for Claude Code. Every step requires your explicit confirmation before proceeding.

## Install

```bash
cd claude-agent
npm run install-ca
```

This copies slash commands to `~/.claude/commands/ca/` and agents to `~/.claude/agents/`.

## Uninstall

```bash
npm run uninstall-ca
```

Removes commands and agents from `~/.claude/`. Project `.dev/` directories are preserved.

## Workflow

```
/ca:init → /ca:discuss → /ca:research (optional) → /ca:plan → /ca:execute → /ca:verify
```

### 1. Initialize — `/ca:init`

Creates a `.dev/` directory in your project for workflow state, context, and history. Asks your preferred interaction language.

### 2. Discuss — `/ca:discuss`

Clarifies your requirements through focused Q&A (one question at a time). Produces a requirement summary that you must confirm before moving on.

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

An independent verifier agent checks every success criterion in a fresh context. After your acceptance, optionally creates a git commit (message confirmed by you). Archives the workflow cycle to `.dev/history/`.

## Other Commands

| Command | Description |
|---------|-------------|
| `/ca:status` | Show current workflow state |
| `/ca:fix [step]` | Roll back to a previous step |
| `/ca:remember <info>` | Save to persistent project context |
| `/ca:context` | Show saved context |
| `/ca:forget <info>` | Remove from context |
| `/ca:todo <item>` | Add a todo item |
| `/ca:todos` | List all todos |
| `/ca:help` | Show command reference |

## Project Structure

```
.dev/                          # Created per-project by /ca:init
  config.md                    # Language preference
  context.md                   # Persistent context (/ca:remember)
  todos.md                     # Todo list
  current/
    STATUS.md                  # Workflow state
    REQUIREMENT.md             # From /ca:discuss
    RESEARCH.md                # From /ca:research
    PLAN.md                    # From /ca:plan
    SUMMARY.md                 # From /ca:execute
  history/
    0001-feature-slug/         # Archived workflow cycles
```

## Agents

| Agent | Role | Why isolated |
|-------|------|-------------|
| `ca-researcher` | Deep codebase analysis | Research consumes large context |
| `ca-executor` | Implements the plan | Code edits cause context bloat |
| `ca-verifier` | Independent verification | Fresh context avoids confirmation bias |

## License

MIT
