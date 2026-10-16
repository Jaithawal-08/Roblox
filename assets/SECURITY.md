# Asset security and import policy

## Scope and honest guarantee

No static review can prove that a file is harmless against every future parser
vulnerability. The practical goal here is narrower and verifiable:

- do not place executable, script, plugin, loader, or redirect content in the
  usable asset library;
- do not import unknown Roblox behavior into the game;
- detect common model backdoor indicators before an import is trusted;
- keep a hash and provenance record so an asset cannot change silently.

The current usable files are inert mesh, texture, sprite, and audio formats
from the sources listed in `SOURCES.md`. Future downloads must pass the same
workflow.

## Threat model

### Roblox free-model backdoors

An `.rbxm`/`.rbxmx` can contain `Script`, `LocalScript`, or `ModuleScript`
instances hidden under a decorative object. Common warning signs include:

- numeric or dynamic `require` calls;
- `HttpService`, `GetAsync`, `RequestAsync`, or external network access;
- `InsertService:LoadAsset` or runtime asset loading;
- `loadstring`, `getfenv`, `setfenv`, `string.char`, packed/encoded payloads;
- runtime creation of server scripts, remotes, admin panels, or DataStore code;
- deceptive names such as `Loader`, `Package`, `Update`, `Free`, or `AntiLag`.

The scanner reports indicators; it does not execute code and it is not a
replacement for reading every imported script.

### Non-Roblox asset files

The relevant risks are supply-chain and parser risks rather than a traditional
“Roblox virus”:

- archive traversal or ZIP bombs;
- disguised executables with a safe-looking extension;
- `.blend` files with embedded Blender Python text blocks;
- malformed images or meshes triggering a vulnerability in an importer;
- archives containing redirects, active content, or unnecessary installers.

The usable library excludes these categories. The validator checks archive
paths, member counts, uncompressed sizes, compression ratios, file signatures,
extensions, and hashes.

## Required workflow for a new asset

1. **Source:** record the official source page, creator, license, direct
   download URL, retrieval date, and intended local path.
2. **Download:** save outside the game place. Do not run, open, or install the
   download. Keep the original URL and compute a SHA-256 hash.
3. **Archive inspection:** list the archive without extracting. Reject
   traversal paths, symlinks, executables, scripts, installers, redirects,
   active content, huge members, and suspicious compression ratios.
4. **Extraction:** copy only required inert formats into a new subfolder. Do
   not preserve unknown files “just in case.”
5. **Manifest:** regenerate `manifest.json` and `LICENSE-LEDGER.csv`.
6. **Validate:** run `python assets/tools/verify_assets.py assets/manifest.json
   --root assets` and require an exit code of 0.
7. **Roblox quarantine:** for a Roblox model, insert into an isolated place or
   quarantine folder; export `.rbxmx`; run `scan_roblox_model.py`.
8. **Human review:** inspect all descendants and every script source in Studio.
   Remove scripts from visual-only content. Never enable a prompt to turn on
   HTTP or install a plugin.
9. **Runtime check:** only after the audit, test the asset in Studio, check the
   console, and playtest collision/performance on a low-end mobile target.

## Scanner verdicts

- `SAFE` — the `.rbxmx` parsed and no embedded scripts were found. This is the
  preferred verdict for visual-only assets.
- `REVIEW` — one or more scripts exist but no known indicator matched. Read the
  scripts manually; do not ship by default.
- `SUSPICIOUS` — a high/medium-risk pattern matched, or `--fail-on-scripts`
  was used on a scripted model. Quarantine or remove it.
- `INVALID` — the input was not safe to parse, was too large, contained unsafe
  XML constructs, or was not `.rbxmx`.

## Commands

```bash
# Validate the checked-in asset library.
python assets/tools/verify_assets.py assets/manifest.json --root assets

# Scan an exported Roblox XML model and reject any embedded scripts.
python assets/tools/scan_roblox_model.py quarantine/model.rbxmx --fail-on-scripts

# JSON output is useful for a review log or CI artifact.
python assets/tools/scan_roblox_model.py quarantine/model.rbxmx --json
```

## Roblox-specific boundary

Do not confuse an imported mesh with trusted gameplay code. The game remains
server-authoritative: ownership, inventory, currency, rewards, theft, and
monetization stay in the project's own reviewed Luau services. Asset files may
provide appearance/audio only. Any imported behavior needs a separate design
review and an explicit security justification.
