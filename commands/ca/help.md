---
name: ca-help
description: Shows the CA command reference with all available commands. Use when user needs help with CA commands.
---
# /ca:help — Command Reference

**CRITICAL — Code Modification Policy**: Read-only display command. Do NOT modify any files.

Read config by running: `node ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ca/scripts/ca:config.js --project-root <project-root>`. Parse the JSON output to get all config values. If the script fails (files missing), execute `Skill(ca:settings)` for initial setup, then continue.

Display all available CA commands in the user's preferred language:

## Setup

| Command | Description |
|---------|-------------|
| `/ca:settings` | Configure language settings (global or workspace) |

## Workflow Commands

| Command | Description |
|---------|-------------|
| `/ca:new [description]` | Start a new requirement — gather brief, create workflow + branch |
| `/ca:quick [description]` | Quick workflow — brief + branch, skip discuss |
| `/ca:discuss` | Discuss requirements — ask clarifying questions, produce confirmed requirement summary |
| `/ca:plan` | Propose implementation plan with **triple confirmation** |
| `/ca:execute` | Execute the confirmed plan (uses ca-executor agent) |
| `/ca:verify` | Self-check + user acceptance (uses ca-verifier agent) |
| `/ca:finish` | Wrap up workflow — version bump, merge branch, archive |
| `/ca:next` | Auto-detect current step and execute the next one |
| `/ca:switch` | Switch active workflow — select from available workflows |
| `/ca:list` | List all workflows with status summary |
| `/ca:batch` | Batch execute workflows — serial with branch/checkpoint mode |

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
| `/ca:map` | Scan project structure and generate/update `.ca/map.md` |
| `/ca:errors` | Show and manage error lessons |
| `/ca:help` | Show this reference |

## Typical Workflow

**Standard:**
```
/ca:new → /ca:discuss → /ca:plan → /ca:execute → /ca:verify → /ca:finish
```
- `/ca:new` and `/ca:quick` create a workflow + dedicated branch
- `/ca:execute` auto-commits changes on the branch
- `/ca:verify` checks results on the branch (if verify fails, issues are recorded and workflow returns to plan)
- `/ca:finish` bumps version, merges branch, and archives the workflow

**Or use `/ca:next` repeatedly to auto-advance through each step.**

**Quick:**
```
/ca:quick → /ca:plan → /ca:execute → /ca:verify → /ca:finish
```
**Or use `/ca:next` repeatedly to auto-advance through each step.**

**Multi-workflow:**
```
/ca:new → /ca:discuss → /ca:plan   (repeat for multiple requirements)
/ca:batch                            (batch execute all confirmed plans, each on its branch)
```

Every step has a **mandatory confirmation point** — nothing proceeds without your explicit approval.
