# AGENTS.md

## Layout

- Repo root (`C:\CodingProjects\Roblox-Game`) is **not** a git repo. `Roblox/` is a clone of
  `https://github.com/Jaithawal-08/Roblox` (friend's project, single squashed commit).
  `opencode.json` at root wires the `roblox-studio` MCP server (el4cteo).
- No README, tests, lint, or CI anywhere. Lua headers and `generate_rbxl.py` are the docs.

## Skills (project-local only)

- `roblox-skills/` is a shallow clone of `AshExplained/roblox-skills` (~40 `SKILL.md` packs:
  Luau architecture, datastores, combat, UI, QA, lifecycle, etc.), wired via
  `"skills": ["./roblox-skills"]` in root `opencode.json`. Nothing is installed globally —
  delete the folder + the config line to remove. Refresh with `git -C roblox-skills pull`.
- Load a pack with the skill tool when its domain matches the task (e.g. datastores,
  combat, playtest-qa); don't bulk-load — each pack is large.

## Source of truth

- The sibling `.lua` files are the sources. `Roblox/generate_rbxl.py` reads them at build
  time (`read_script(...)`, ~line 192) — it does **not** embed copies, so edit the `.lua` files.
- Regenerate with `python Roblox/generate_rbxl.py`. Gotcha: the script writes
  `ShadowRealm_Stage1.rbxl`, but the tracked artifact is `ShadowRealm_Stage1.rbxlx` — a
  regen creates a *new* file, it does not update the `.rbxlx`. (Python 3.13 verified.)
- `Roblox/StudioSetup.lua` is an alternate in-Studio builder (paste into Command Bar / Run).
  Prefer MCP pushes for iterative edits; full regen + reopen discards live Studio state.

## Deploying scripts into Studio

- Every `.lua` file's header has a `Place in:` line mapping it to its DataModel home
  (e.g. `ServerScriptService > Services > PlayerDataService`). Read it before creating/moving
  scripts via MCP — filenames alone mislead (see below).
- `MainHUD_LocalScript.lua` is inserted as `HUDController`, not `MainHUD` (`generate_rbxl.py:434`).
- Load order matters: `RemotesSetup` (plain Script, runs immediately) **must** execute before
  `PlayerDataService`, which depends on `ReplicatedStorage.Remotes` existing.
- `TestScript.lua` is testing-only (free XP/coins) — **delete it before any publish**.

## Live Studio workflow (el4cteo MCP)

- Start sessions with `studio_status`; if several Studio windows are connected, use
  `list_studios` + `set_active_studio` — never assume the target.
- Prefer batch tools (`create`/`modify`/`delete`/`move`/`script_edit` take arrays): one call =
  one undo step. `execute_luau` is the escape hatch, not the default.
- To push a local `.lua` edit into the open place, use `script_edit`/`script_create` with the
  file contents (the repo is flat files, not the Rojo `./studio` layout `sync push` expects).
