# /ca:settings — Configure Settings

Read `~/.claude/ca/config.md` for global config, then read `.ca/config.md` for workspace config. Workspace values override global values. If neither exists, default to English.

Read and follow the rules defined in `commands/ca/_rules.md` (installed at `~/.claude/commands/ca/_rules.md`).

## Behavior

### 1. Choose save location

Ask the user where to save the configuration using `AskUserQuestion`:
- **Global** (`~/.claude/ca/config.md`) — applies to all projects
- **Workspace** (`.ca/config.md`) — applies to this project only, overrides global

### 2. Load existing config

Read the config file for the chosen location (if it exists). Also read the global config if the user chose workspace (to show inherited values).

### 3. Configure each setting

For each setting, ask the user ONE AT A TIME using `AskUserQuestion`:

#### `interaction_language` — Language for conversations

Options: English, 中文 (Chinese), or custom input.

- If editing workspace config and user wants to inherit from global, they can choose "Inherit from global".
- If the setting already has a value, show the current value and let user keep it.

#### `comment_language` — Language for code comments

Same options as above.

#### `code_language` — Language for code strings (logs, error messages, etc.)

Same options as above.

#### `model_profile` — Model profile for agent execution

Options: `quality`, `balanced`, `budget`.

- `quality`: executor=opus, researcher=opus, verifier=sonnet
- `balanced`: executor=sonnet, researcher=sonnet, verifier=sonnet
- `budget`: executor=sonnet, researcher=haiku, verifier=haiku

Default: `balanced`. If the setting already has a value, show the current value and let user keep it.

#### Per-agent model overrides (optional)

Ask the user if they want to override the model for any specific agent. If yes, ask ONE AT A TIME:

- `ca-executor_model` — Override model for executor agent
- `ca-researcher_model` — Override model for researcher agent
- `ca-verifier_model` — Override model for verifier agent

Options for each: `opus`, `sonnet`, `haiku`, or leave empty to use profile default.

Per-agent overrides take priority over the profile setting.

#### `auto_proceed_to_plan` — Auto-proceed from research to plan

Options: `true`, `false`.

Default: `false`. When `true`, research will automatically invoke plan after findings are confirmed, without requiring the user to manually run `/ca:plan`.

#### `auto_proceed_to_verify` — Auto-proceed from execute to verify

Options: `true`, `false`.

Default: `false`. When `true`, execute will automatically invoke verify after execution is complete, without requiring the user to manually run `/ca:verify`.

### 4. Write config

Write the config to the chosen location:

```markdown
# CA Configuration

interaction_language: <value>
comment_language: <value>
code_language: <value>
model_profile: <value>
ca-executor_model: <value>
ca-researcher_model: <value>
ca-verifier_model: <value>
auto_proceed_to_plan: <value>
auto_proceed_to_verify: <value>
```

For workspace config, omit settings that inherit from global (do not write them).
Omit per-agent model overrides that are empty (not set).
Omit auto_proceed settings that are `false` (default).

### 5. Confirm

Show the user the final configuration and which file it was saved to.
