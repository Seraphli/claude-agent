# /ca:context — Show Persistent Context

Read `~/.claude/ca/config.md` for global config, then read `.dev/config.md` for workspace config. Workspace values override global values. If neither exists, default to English. Respond in the configured `interaction_language`.

## Prerequisites

Check `.dev/context.md` exists. If not, tell the user to run `/ca:new` first and stop.

## Behavior

Read and display the contents of `.dev/context.md`.

If the file is empty (only has the header), tell the user there's no saved context yet and suggest using `/ca:remember <info>` to add some.
