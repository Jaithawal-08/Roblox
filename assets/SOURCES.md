# Asset source research and provenance

Research and downloads were completed on **2026-10-15**. The objective was a
large, useful library for original brainrot-style creatures and the zones,
dens, UI feedback, and audio around them, while avoiding backdoors, unclear
redistribution rights, malware/bloatware, and copied meme IP.

## Decision: original brainrot-style, not named Italian brainrot

The project PRD says “cute beasts with meme-able names,” not a requirement to
copy characters from a particular meme. That distinction is important. Names
and designs such as Tralalero Tralala, Tung Tung Tung Sahur, and Bombardiro
Crocodilo are legally contested in current reporting, including an active
dispute around rights and takedown demands. A free download is not a free
commercial license.

This library therefore uses generic, licensable creature art as raw material.
Give the final beasts original silhouettes, colours, names, animations, and
audio. Do not ship a source model with an existing meme character's name or
branding.

## Selected sources

### Quaternius — creatures

The official pack pages below state **CC0** for the selected legacy packs and
link to the author's Google Drive downloads. The usable library contains only
inert model/texture formats; Blender files were deliberately excluded.

| Local path | Official pack page | Pack-linked download | Use |
|---|---|---|---|
| `beasts/quaternius/cute-monsters/` | https://quaternius.com/packs/cutemonsters.html | https://drive.google.com/drive/folders/1zLLO_7ZoWgUsS4uooYnVSErQYRu1VdS0?usp=sharing | 21 cute animated monsters; primary beast silhouettes |
| `beasts/quaternius/animated-monsters/` | https://quaternius.com/packs/animatedmonster.html | https://drive.google.com/drive/folders/102H-oyUM8SGYi1mW0GOgkjEu7xSdaORA?usp=sharing | compact monster variants |
| `beasts/quaternius/animated-aliens/` | https://quaternius.com/packs/animatedalien.html | https://drive.google.com/drive/folders/1ADdETHqjSIEUhjKjhLB9hQjeppXEqcvL?usp=sharing | unusual late-zone silhouettes |
| `beasts/quaternius/ultimate-nature/` | https://quaternius.com/packs/ultimatenature.html | https://drive.google.com/drive/folders/1-Kl0L_Jg8awbh0S5T-z3zxh4mVlnxTpa?usp=sharing | nature/biome support and creature-adjacent props |
| `beasts/quaternius/ultimate-fantasy-rts/` | https://quaternius.com/packs/ultimatefantasyrts.html | https://drive.google.com/drive/folders/1h7sztlZyavWla-JDk3jp6KiWDdMh08yd?usp=sharing | optional fantasy props/creature references |

**License caution:** Quaternius now publishes a newer QAL for some packs. Do
not infer that every current Quaternius pack is CC0. The local selections are
covered by the legacy pack pages above as researched; re-check the specific
pack page before adding another Quaternius download. Never redistribute a pack
as a standalone asset product.

### Kenney — environment, sprites, and audio

The selected Kenney pages are first-party and identify the assets as **CC0**.
The direct ZIP URLs below were used as the source downloads. Only inert game
formats were extracted; source metadata, redirect files, SVG/SWF previews, and
other non-required files were not copied into the usable library.

| Local path | Official page | Direct ZIP | Use |
|---|---|---|---|
| `environment/kenney/nature-kit/` | https://kenney.nl/assets/nature-kit | https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip | Trailhead, forest, and biome dressing |
| `environment/kenney/graveyard-kit/` | https://kenney.nl/assets/graveyard-kit | https://kenney.nl/media/pages/assets/graveyard-kit/ba8d4b4517-1760691807/kenney_graveyard-kit_5.0.zip | Shadow/event dressing |
| `environment/kenney/mini-dungeon/` | https://kenney.nl/assets/mini-dungeon | https://kenney.nl/media/pages/assets/mini-dungeon/6cd72dc849-1785314274/kenney_mini-dungeon.zip | den interiors and Guardian spaces |
| `environment/kenney/city-kit-roads/` | https://kenney.nl/assets/city-kit-roads | https://kenney.nl/media/pages/assets/city-kit-roads/74288c9459-1791628607/kenney_city-kit-roads.zip | industrial/cosmic route pieces |
| `environment/kenney/city-kit-industrial/` | https://kenney.nl/assets/city-kit-industrial | https://kenney.nl/media/pages/assets/city-kit-industrial/0ec35b139d-1788171848/kenney_city-kit-industrial_2.0.zip | shops, base/den props, later zones |
| `sprites/kenney/monster-builder-pack/` | https://kenney.nl/assets/monster-builder-pack | https://kenney.nl/media/pages/assets/monster-builder-pack/663e4ef6de-1677495438/kenney_monster-builder-pack.zip | 2D portrait/icon parts |
| `sprites/kenney/platformer-art-extended-enemies/` | https://kenney.nl/assets/platformer-art-extended-enemies | https://kenney.nl/media/pages/assets/platformer-art-extended-enemies/38f1885b37-1677696504/kenney_platformer-art-extended-enemies.zip | silhouettes, icons, enemy UI |
| `sprites/kenney/animal-pack-remastered/` | https://kenney.nl/assets/animal-pack-remastered | https://kenney.nl/media/pages/assets/animal-pack-remastered/54a307a369-1774771709/kenney_animal-pack-remastered.zip | supporting animal sprites |
| `audio/kenney/rpg-audio/` | https://kenney.nl/assets/rpg-audio | https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip | footsteps, ambience, game feedback |
| `audio/kenney/impact-sounds/` | https://kenney.nl/assets/impact-sounds | https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip | catch, hit, delivery, reward feedback |
| `audio/kenney/digital-audio/` | https://kenney.nl/assets/digital-audio | https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip | UI and progression feedback |

Kenney audio still needs to be imported through Roblox's current audio
workflow. A CC0 source license does not automatically create a public Roblox
audio asset; upload/permission rules and moderation still apply.

### Poly Haven — material maps

Poly Haven's official license is CC0: https://polyhaven.com/license. The local
files are 1K maps selected for mobile-friendly Roblox material experiments.

| Local files | Source page | Source API |
|---|---|---|
| `materials/polyhaven/wood_floor_*_1k.*` | https://polyhaven.com/a/wood_floor | https://api.polyhaven.com/files/wood_floor |
| `materials/polyhaven/aerial_rocks_04_*_1k.*` | https://polyhaven.com/a/aerial_rocks_04 | https://api.polyhaven.com/files/aerial_rocks_04 |

Only JPG/PNG maps were retained. EXR, Blender, glTF, and other authoring
formats were not needed for this Roblox import set.

## Why Roblox Toolbox models were not downloaded

Roblox's Creator Store contains assets from Roblox and independent creators;
the marketplace itself is not a blanket safety guarantee. Roblox's security
guidance and creator discussions describe risks including hidden scripts,
obfuscated source, `require(assetId)` loaders, and code that inserts or spreads
other instances. A decorative model that asks for `HttpService`, a plugin, or
Command Bar code is not an acceptable dependency for this project.

The project rule is therefore:

1. Prefer inert FBX/OBJ/glTF/PNG/audio files from a first-party licensed source.
2. If a Roblox model is ever needed, insert it into a quarantine folder in an
   isolated place.
3. Inspect every `Script`, `LocalScript`, and `ModuleScript`; delete scripts
   from visual-only assets.
4. Run `assets/tools/scan_roblox_model.py` on an exported `.rbxmx` and review
   the Studio tree before trusting it.
5. Reject obfuscated, networked, dynamically required, or unexplained code.

Relevant official guidance:

- Creator Store: https://create.roblox.com/docs/production/creator-store
- Third-party vulnerabilities: https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities
- Capabilities: https://create.roblox.com/docs/scripting/capabilities

## Sources deliberately excluded

- **Named Italian brainrot character models:** legally contested and not
  necessary for the game's original-beast promise.
- **Arbitrary Roblox Toolbox/free models:** potential backdoors and unclear
  source ownership; none are required when importing inert meshes.
- **Unlicensed Sketchfab/CGTrader/itch.io mirrors:** “free download” is not an
  item-level commercial license. They may be researched later one file at a
  time, but are not part of this verified set.
- **OpenGameArt/Freesound bulk downloads:** licenses are item-specific and can
  be CC-BY, CC-BY-SA, or CC-BY-NC. The safer first pass uses Kenney CC0 audio
  and sprite packs instead.
- **`.blend` files from Quaternius:** source files can contain embedded
  Blender Python text blocks. They remain outside the usable library.

## Retrieval and integrity notes

The downloaded source archives were inspected before extraction. Archive
members were checked for traversal paths, symlink entries, executable/script
extensions, and unreasonable sizes. Only the inert allow-list described in
`README.md` was copied into this folder. The original archives were then
removed from the workspace so they cannot be accidentally imported with their
redirect/metadata files.

`manifest.json` is generated from the files that remain in this folder and
contains their SHA-256 hashes. `LICENSE-LEDGER.csv` records source page, direct
download URL, license, and the hash of every retained file. If an asset is
re-downloaded, regenerate the manifest/ledger and re-run the validator rather
than silently replacing it.

## Asset-use boundary

CC0 resolves the copyright license for the referenced asset, not every legal
question about a finished game. It does not grant permission to use a logo,
trademark, recognizable real person, third-party character, or copied game
identity. Final beast names and designs must remain original and kid-safe.
