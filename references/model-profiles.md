# Model Profiles

Three predefined profiles for agent model assignment. Use `model_profile` in config to select one.

## Profiles

| Agent | quality | balanced | budget |
|-------|---------|----------|--------|
| ca-executor | opus | sonnet | sonnet |
| ca-researcher | opus | sonnet | haiku |
| ca-verifier | sonnet | sonnet | haiku |

## Priority

Model resolution order (highest to lowest):
1. Per-agent override in config (e.g., `ca-executor_model: opus`)
2. Profile tier from `model_profile` setting
3. Default: `balanced` profile
