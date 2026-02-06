# /ca:context — Show Persistent Context

Read `.dev/config.md` to determine the user's preferred language. Respond in that language.

## Prerequisites

Check `.dev/context.md` exists. If not, tell the user to run `/ca:init` first and stop.

## Behavior

Read and display the contents of `.dev/context.md`.

If the file is empty (only has the header), tell the user there's no saved context yet and suggest using `/ca:remember <info>` to add some.
