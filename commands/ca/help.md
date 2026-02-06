# /ca:help — Command Reference

Read `.dev/config.md` to determine the user's preferred language. If the file doesn't exist, default to English.

Display all available CA commands in the user's preferred language:

## Workflow Commands

| Command | Description |
|---------|-------------|
| `/ca:init` | Initialize workspace — creates `.dev/` directory, sets language preference |
| `/ca:discuss` | Discuss requirements — ask clarifying questions, produce confirmed requirement summary |
| `/ca:research` | Analyze codebase + external resources (optional step) |
| `/ca:plan` | Propose implementation plan with **triple confirmation** |
| `/ca:execute` | Execute the confirmed plan (uses ca-executor agent) |
| `/ca:verify` | Self-check + user acceptance + git commit confirmation (uses ca-verifier agent) |

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
| `/ca:help` | Show this reference |

## Typical Workflow

```
/ca:init → /ca:discuss → /ca:research (optional) → /ca:plan → /ca:execute → /ca:verify
```

Every step has a **mandatory confirmation point** — nothing proceeds without your explicit approval.
