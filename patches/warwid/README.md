# Warwid Patch Queue

These patches are parent-repo artifacts for changes that belong in external module submodules.

Do not update the parent repository to point at a local-only submodule commit. For a patch to become live in local Docker images, apply it during the build stage before CMake configures modules. For a longer-term module fix, either:

1. Apply it in a fork of the module, push that fork, and update `.gitmodules` plus the submodule commit; or
2. Submit it upstream and update the submodule after upstream merges it.

## `mod-autobalance-console-null-session.patch`

Purpose:

- Fix AutoBalance command handlers that are declared `Console::Yes` but dereference `handler->GetSession()` when run from the bare worldserver console.
- Allow `.ab getoffset` and `.ab setoffset` to use the default locale from console.
- Make `.ab mapstat` and `.ab creaturestat` fail cleanly without an in-game player context.

Live evidence:

- `server info` succeeded through pseudo-TTY console attach.
- `.ab getoffset` restarted `ac-worldserver` on 2026-07-01.
- Jira follow-up: `EMBER-62`.

Apply from `modules/mod-autobalance`:

```bash
git apply ../../patches/warwid/mod-autobalance-console-null-session.patch
```

The Warwid Docker build applies this patch automatically in `apps/docker/Dockerfile` before CMake runs.
