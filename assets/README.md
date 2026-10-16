# Snatch a Beast asset library

This folder contains the **safe, inert asset subset** selected for the
brainrot-style beast direction of *Snatch a Beast*. The library is deliberately
original and stylised: it does **not** contain Italian-brainrot characters,
Roblox free models, plugins, scripts, loaders, or executable files.

## What is included

- `beasts/quaternius/` — CC0 FBX/OBJ/glTF creature source models from
  Quaternius' official pack-linked downloads. Blender source files were not
  copied into the usable library because `.blend` files can contain embedded
  Blender Python text blocks.
- `environment/kenney/` — CC0 environment and prop art from official Kenney
  ZIP downloads for nature, graveyard, dungeon, roads, and industrial zones.
- `sprites/kenney/` — CC0 2D monster, enemy, and animal sprite art.
- `audio/kenney/` — CC0 gameplay/UI/impact audio.
- `materials/polyhaven/` — 1K CC0 JPG/PNG material maps selected for Roblox
  import budgets.
- `tools/` — dependency-free Python validators for the manifest and future
  Roblox `.rbxmx` imports.
- `manifest.json` — SHA-256 and size manifest for every usable asset file.
- `LICENSE-LEDGER.csv` — per-file provenance and license summary.
- `SOURCES.md` — source research, URLs, retrieval notes, and exclusions.
- `SECURITY.md` — threat model, import procedure, and audit limits.

Current checked-in inventory: **5,542 retained files / 119,361,916 bytes** —
257 creature-model files, 4,251 environment files, 783 sprite files, 245
audio files, and 6 material maps. The number is intentionally the clean,
importable subset rather than the raw source-pack total.

## Safe integration rule

Treat this directory as an **asset source library**, not as a Roblox place
package. Import only the visual/audio files you need into Studio. Keep them in
a quarantine folder first, inspect the resulting instances, and remove any
unexpected scripts before moving them into the game. The assets here are inert
files, but no scanner can prove that an arbitrary future download is harmless.

The ready-to-use library intentionally excludes:

- `.rbxm`/`.rbxmx` models from unknown creators;
- `.lua`, `.luau`, `.py`, `.js`, shell, executable, installer, or plugin files;
- `.blend` source files with possible embedded Blender scripts;
- redirect/active-content files such as `.url`, `.swf`, `.html`, `.svg`, and
  `.xml` metadata from source archives;
- real-world meme characters or copied Roblox/third-party IP.

## Verification

From the repository root:

```bash
python assets/tools/verify_assets.py assets/manifest.json --root assets
```

The command must print `Validated ... asset(s) successfully.` before this
library is used. It checks relative paths, symlinks, allowed formats, file
signatures where practical, file sizes, SHA-256 hashes, and bounded ZIP
contents. The manifest currently covers extracted usable files; the original
source archives are intentionally not retained in the workspace.

After adding or replacing a retained asset, regenerate the two machine-readable
records first:

```bash
python assets/tools/build_manifest.py --root assets --date 2026-10-15
python assets/tools/verify_assets.py assets/manifest.json --root assets
```

For a future Roblox XML model exported from Studio:

```bash
python assets/tools/scan_roblox_model.py path/to/model.rbxmx --fail-on-scripts
```

`SAFE` means no embedded script was found in the scanned XML, not that the
asset is guaranteed bug-free or legally usable. `REVIEW` means a script exists
and needs human review; `SUSPICIOUS` or `INVALID` must not be imported.

## Roblox import notes

The Quaternius FBX/glTF/OBJ files are source meshes, not Roblox instances or
animation-ready Roblox rigs. Import them in Studio/Blender in an isolated
place, apply the project's scale/silhouette rules, and keep the final scene
within the mobile performance budget. Do not copy a source file into
`ReplicatedStorage` expecting it to run; the server/client scripts remain the
project's own source of truth under `Roblox/`.

All license and source decisions are recorded in `SOURCES.md` and
`LICENSE-LEDGER.csv`. See `SECURITY.md` before importing anything from outside
this folder.
