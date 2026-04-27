# Todos File Migration

One-time migration from the legacy single-file layout (`.ca/todos.md` containing both `# Todo List` and `# Archive` sections) to the split layout (`.ca/todos.md` with only `# Todo List`, `.ca/todos-archive.md` with `# Archive`).

## Trigger

Before reading or writing `.ca/todos.md` in any CA command that touches todos, check whether it contains a legacy archive section. Trigger migration iff both of these hold:

1. `.ca/todos.md` exists.
2. Its content contains at least one line that equals `# Archive` (the legacy archive header).

If either condition is false, skip migration.

## Procedure

Use only the `Read` and `Write`/`Edit` tools — never `Bash` (cat/echo/sed/awk).

1. Read `.ca/todos.md`.
2. Locate the first line that equals `# Archive` (exact match after trimming trailing whitespace).
3. Split the file content into two parts:
   - **Active part**: all content above the `# Archive` line (including the `# Todo List` header and any active items).
   - **Archive part**: the `# Archive` line and everything below (including all archived items).
4. Trim trailing blank lines from the active part. Ensure it ends with exactly one newline.
5. Write `.ca/todos.md` with only the active part.
6. Handle `.ca/todos-archive.md`:
   - If it does not exist: write it with the archive part verbatim (starting with `# Archive`).
   - If it exists: Read it. Take everything after the first `# Archive` header line from the archive part (the archived items only, no duplicate header). Append those items to the end of the existing `.ca/todos-archive.md`, preserving a blank line separator if needed.
7. Save.

## Idempotence

After step 5, `.ca/todos.md` no longer contains `# Archive`. Re-running migration is a no-op because the trigger condition fails.
