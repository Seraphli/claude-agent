# /ca:help — Command Reference

Display all available CA commands in the user's preferred language:

## Setup

| Command | Description |
|---------|-------------|
| `/ca:settings` | Configure language settings (global or workspace) |

## Workflow Commands

| Command | Description |
|---------|-------------|
| `/ca:new [description]` | Start a new requirement — creates `.ca/` directory, collects initial brief |
| `/ca:quick [description]` | Quick workflow — skip discuss & research, go straight to plan |
| `/ca:discuss` | Discuss requirements — ask clarifying questions, produce confirmed requirement summary |
| `/ca:research` | Analyze codebase + external resources (optional step) |
| `/ca:plan` | Propose implementation plan with **triple confirmation** |
| `/ca:execute` | Execute the confirmed plan (uses ca-executor agent) |
| `/ca:verify` | Self-check + user acceptance + git commit confirmation (uses ca-verifier agent) |
| `/ca:next` | Auto-detect current step and execute the next one |

## Context Management

| Command | Description |
|---------|-------------|
| `/ca:remember <info>` | Save information to persistent context |
| `/ca:context` | Display current persistent context |
| `/ca:forget <info>` | Remove information from context |

## Todo Management

| Command | Description |
|---------|-------------|
| `/ca:todo <item>` | Add a todo item |
| `/ca:todos` | List all todo items |

## Navigation

| Command | Description |
|---------|-------------|
| `/ca:status` | Show current workflow status |
| `/ca:fix [step]` | Roll back to a previous step |
| `/ca:map` | Scan project structure and generate/update `.ca/map.md` |
| `/ca:help` | Show this reference |

## Typical Workflow

**Standard:**
```
/ca:new → /ca:discuss → /ca:research (optional) → /ca:plan → /ca:execute → /ca:verify
```
**Or use `/ca:next` repeatedly to auto-advance through each step.**

**Quick:**
```
/ca:quick → /ca:plan → /ca:execute → /ca:verify
```
**Or use `/ca:next` repeatedly to auto-advance through each step.**

Every step has a **mandatory confirmation point** — nothing proceeds without your explicit approval.
