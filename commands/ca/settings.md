# /ca:settings — Configure Language Settings

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English.

## Behavior

### 1. Choose save location

Ask the user where to save the configuration using `AskUserQuestion`:
- **Global** (`~/.claude/ca/config.md`) — applies to all projects
- **Workspace** (`.dev/config.md`) — applies to this project only, overrides global

### 2. Load existing config

Read the config file for the chosen location (if it exists). Also read the global config if the user chose workspace (to show inherited values).

### 3. Configure each setting

For each of the three settings, ask the user ONE AT A TIME using `AskUserQuestion`:

#### `interaction_language` — Language for conversations

Options: English, 中文 (Chinese), or custom input.

- If editing workspace config and user wants to inherit from global, they can choose "Inherit from global".
- If the setting already has a value, show the current value and let user keep it.

#### `comment_language` — Language for code comments

Same options as above.

#### `code_language` — Language for code strings (logs, error messages, etc.)

Same options as above.

### 4. Write config

Write the config to the chosen location:

```markdown
# CA Configuration

interaction_language: <value>
comment_language: <value>
code_language: <value>
```

For workspace config, omit settings that inherit from global (do not write them).

### 5. Confirm

Show the user the final configuration and which file it was saved to.
