#!/usr/bin/env python3
"""Validate a small, explicit asset manifest without opening or executing assets.

The manifest is JSON and may either be a list of entries or an object containing
an ``assets`` or ``files`` list. Each entry must contain ``path`` and a
hexadecimal ``sha256`` digest. Paths are relative to the manifest directory
unless ``--root`` is supplied.

The extension allow-list is deliberately conservative. A Roblox model can
contain Luau source as data, but standalone source files and native executables
are never accepted as distributable assets by this validator.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import zipfile
import xml.etree.ElementTree as ET


DEFAULT_MAX_MANIFEST_SIZE = 8 * 1024 * 1024
DEFAULT_MAX_FILE_SIZE = 512 * 1024 * 1024
DEFAULT_MAX_ARCHIVE_MEMBERS = 10_000
DEFAULT_MAX_ARCHIVE_MEMBER_SIZE = 256 * 1024 * 1024
DEFAULT_MAX_ARCHIVE_TOTAL_SIZE = 512 * 1024 * 1024
DEFAULT_MAX_COMPRESSION_RATIO = 1_000.0
HASH_CHUNK_SIZE = 1024 * 1024

# Roblox project data and common binary media formats. Unknown formats are
# rejected rather than guessed at, so a renamed executable cannot pass.
ALLOWED_EXTENSIONS = frozenset(
    {
        ".rbxm", ".rbxl", ".rbxmx", ".rbxlx",
        ".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tga",
        ".ogg", ".mp3", ".wav", ".flac",
        ".fbx", ".obj", ".mtl", ".gltf", ".glb", ".zip",
    }
)

SUSPICIOUS_EXTENSIONS = frozenset(
    {
        ".exe", ".dll", ".so", ".dylib", ".bin", ".com", ".scr", ".msi", ".msp",
        ".app", ".dmg", ".apk", ".ipa", ".jar", ".class",
        ".py", ".pyw", ".lua", ".luau", ".js", ".jsx", ".ts", ".tsx",
        ".vbs", ".vbe", ".wsf", ".wsh", ".ps1", ".psm1", ".bat", ".cmd",
        ".sh", ".bash", ".zsh", ".fish", ".rb", ".php", ".pl", ".cgi", ".hta", ".reg",
        # Active-content and redirect formats are not needed by this asset
        # library and are rejected even when they are not native executables.
        ".swf", ".url", ".desktop", ".html", ".htm", ".svg", ".xml",
    }
)

EXECUTABLE_MAGICS = (
    (b"MZ", "PE/Windows executable"),
    (b"\x7fELF", "ELF executable"),
    (b"\xfe\xed\xfa\xce", "Mach-O executable"),
    (b"\xce\xfa\xed\xfe", "Mach-O executable"),
    (b"\xfe\xed\xfa\xcf", "Mach-O executable"),
    (b"\xcf\xfa\xed\xfe", "Mach-O executable"),
    (b"#!", "script shebang"),
)


class ValidationError(Exception):
    """A user-correctable validation failure."""


def _positive_int(value: str) -> int:
    try:
        parsed = int(value, 10)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def _positive_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be a number") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def _read_limited(path: Path, limit: int, description: str) -> bytes:
    try:
        with path.open("rb") as handle:
            data = handle.read(limit + 1)
    except OSError as exc:
        raise ValidationError(f"cannot read {description}: {exc}") from exc
    if len(data) > limit:
        raise ValidationError(f"{description} exceeds the {limit} byte limit")
    return data


def _ensure_regular_file(path: Path, description: str) -> os.stat_result:
    try:
        info = path.lstat()
    except OSError as exc:
        raise ValidationError(f"missing {description}: {exc}") from exc
    if path.is_symlink():
        raise ValidationError(f"{description} must not be a symbolic link")
    if not os.path.isfile(path):
        raise ValidationError(f"{description} is not a regular file")
    return info


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _reject_symlink_components(path: Path, root: Path) -> None:
    """Reject symlinks in the path, including a symlinked parent directory."""
    relative = path.relative_to(root)
    current = root
    for part in relative.parts:
        current /= part
        try:
            if current.is_symlink():
                raise ValidationError(f"asset path contains a symbolic link: {path}")
        except OSError as exc:
            raise ValidationError(f"cannot inspect asset path {path}: {exc}") from exc


def _load_manifest(path: Path, max_size: int) -> list[dict[str, object]]:
    _ensure_regular_file(path, "manifest")
    raw = _read_limited(path, max_size, "manifest")
    try:
        parsed = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"manifest must be UTF-8 JSON: {exc}") from exc

    if isinstance(parsed, list):
        entries = parsed
    elif isinstance(parsed, dict):
        entries = parsed.get("assets", parsed.get("files"))
        if entries is None:
            raise ValidationError("manifest object must contain an 'assets' or 'files' list")
    else:
        raise ValidationError("manifest root must be a list or object")

    if not isinstance(entries, list):
        raise ValidationError("manifest assets/files value must be a list")
    normalized: list[dict[str, object]] = []
    for index, entry in enumerate(entries, start=1):
        if not isinstance(entry, dict):
            raise ValidationError(f"manifest entry {index} must be an object")
        normalized.append(entry)
    return normalized


def _validate_relative_asset_path(raw_path: object, root: Path, manifest_path: Path) -> Path:
    if not isinstance(raw_path, str) or not raw_path.strip():
        raise ValidationError("entry path must be a non-empty string")
    if "\x00" in raw_path:
        raise ValidationError("asset path must not contain NUL bytes")
    candidate = Path(raw_path)
    if candidate.is_absolute() or "\\" in raw_path:
        raise ValidationError(f"asset path must be relative and use '/': {raw_path!r}")
    lexical = root / candidate
    # Check the lexical path before resolving it. Path.resolve() would erase a
    # symlink component and make a link appear to be an ordinary in-root file.
    _reject_symlink_components(lexical, root)
    resolved = lexical.resolve(strict=False)
    if not _is_within(resolved, root):
        raise ValidationError(f"asset path escapes root: {raw_path!r}")
    _reject_symlink_components(resolved, root)
    if resolved == manifest_path.resolve():
        raise ValidationError("manifest cannot list itself as an asset")
    return resolved


def _validate_digest(value: object, entry_number: int) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", value):
        raise ValidationError(
            f"entry {entry_number} sha256 must be exactly 64 hexadecimal characters"
        )
    return value.lower()


def _check_extension(path: Path, entry: dict[str, object], entry_number: int) -> str:
    extension = path.suffix.lower()
    if extension in SUSPICIOUS_EXTENSIONS:
        raise ValidationError(f"entry {entry_number} has rejected executable/script extension {extension}")
    if extension not in ALLOWED_EXTENSIONS:
        raise ValidationError(
            f"entry {entry_number} has unsupported extension {extension or '<none>'}"
        )
    declared = entry.get("extension")
    if declared is not None:
        if not isinstance(declared, str) or declared.lower() != extension:
            raise ValidationError(f"entry {entry_number} extension does not match the asset path")
    return extension


def _check_executable_magic(prefix: bytes, entry_number: int) -> None:
    for magic, description in EXECUTABLE_MAGICS:
        if prefix.startswith(magic):
            raise ValidationError(f"entry {entry_number} begins with a {description}")


def _check_xml_magic(entry_number: int, data: bytes) -> None:
    upper = data[:2 * 1024 * 1024].upper()
    if b"<!DOCTYPE" in upper or b"<!ENTITY" in upper:
        raise ValidationError(f"entry {entry_number} XML contains a DTD/entity declaration")
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ValidationError(f"entry {entry_number} is not valid UTF-8 XML: {exc}") from exc
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise ValidationError(f"entry {entry_number} is not well-formed XML: {exc}") from exc
    if root.tag.rsplit("}", 1)[-1].lower() != "roblox":
        raise ValidationError(f"entry {entry_number} XML root is not <roblox>")


def _check_magic(extension: str, path: Path, entry_number: int, size: int) -> None:
    # Read a bounded prefix without treating the remaining bytes as a size
    # violation. `_read_limited` is intentionally strict for whole-file reads,
    # while signature checks only need the beginning of a large media file.
    try:
        with path.open("rb") as handle:
            data = handle.read(min(size, 64 * 1024))
    except OSError as exc:
        raise ValidationError(f"cannot read asset entry {entry_number}: {exc}") from exc
    _check_executable_magic(data[:16], entry_number)

    if extension in {".rbxmx", ".rbxlx"}:
        full = data if size <= 64 * 1024 else _read_limited(path, size, f"asset entry {entry_number}")
        _check_xml_magic(entry_number, full)
    elif extension == ".png" and not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValidationError(f"entry {entry_number} does not have a PNG signature")
    elif extension in {".jpg", ".jpeg"} and not data.startswith(b"\xff\xd8\xff"):
        raise ValidationError(f"entry {entry_number} does not have a JPEG signature")
    elif extension == ".gif" and not data.startswith((b"GIF87a", b"GIF89a")):
        raise ValidationError(f"entry {entry_number} does not have a GIF signature")
    elif extension == ".webp" and not (data.startswith(b"RIFF") and data[8:12] == b"WEBP"):
        raise ValidationError(f"entry {entry_number} does not have a WebP signature")
    elif extension == ".bmp" and not data.startswith(b"BM"):
        raise ValidationError(f"entry {entry_number} does not have a BMP signature")
    elif extension == ".ogg" and not data.startswith(b"OggS"):
        raise ValidationError(f"entry {entry_number} does not have an Ogg signature")
    elif extension == ".flac" and not data.startswith(b"fLaC"):
        raise ValidationError(f"entry {entry_number} does not have a FLAC signature")
    elif extension == ".wav" and not (data.startswith(b"RIFF") and data[8:12] == b"WAVE"):
        raise ValidationError(f"entry {entry_number} does not have a WAV signature")
    elif extension == ".mp3" and not (
        data.startswith(b"ID3") or (len(data) >= 2 and data[0] == 0xFF and data[1] & 0xE0 == 0xE0)
    ):
        raise ValidationError(f"entry {entry_number} does not have an MP3 signature")
    elif extension == ".zip" and not data.startswith((b"PK\x03\x04", b"PK\x05\x06", b"PK\x07\x08")):
        raise ValidationError(f"entry {entry_number} does not have a ZIP signature")


def _check_zip_limits(
    path: Path,
    entry_number: int,
    max_members: int,
    max_member_size: int,
    max_total_size: int,
    max_ratio: float,
) -> None:
    try:
        archive = zipfile.ZipFile(path, "r")
    except (OSError, zipfile.BadZipFile, RuntimeError) as exc:
        raise ValidationError(f"entry {entry_number} is not a readable ZIP archive: {exc}") from exc

    total_size = 0
    try:
        try:
            members = archive.infolist()
        except (OSError, zipfile.BadZipFile, RuntimeError, ValueError) as exc:
            raise ValidationError(f"entry {entry_number} has an unreadable ZIP directory: {exc}") from exc
        if len(members) > max_members:
            raise ValidationError(f"entry {entry_number} ZIP has too many members ({len(members)})")
        root = Path(".").resolve()
        for member in members:
            name = member.filename
            if not name or "\x00" in name or name.startswith(("/", "\\")):
                raise ValidationError(f"entry {entry_number} ZIP contains an unsafe member path")
            parts = name.replace("\\", "/").split("/")
            if any(part in {"", "."} for part in parts[:-1]) or any(part == ".." for part in parts):
                raise ValidationError(f"entry {entry_number} ZIP contains traversal member {name!r}")
            if len(parts[0]) >= 2 and parts[0][1] == ":":
                raise ValidationError(f"entry {entry_number} ZIP contains drive-qualified member {name!r}")
            normalized = (root / Path(*parts)).resolve()
            if not _is_within(normalized, root):
                raise ValidationError(f"entry {entry_number} ZIP member escapes its root")
            member_suffix = Path(*parts).suffix.lower()
            if member_suffix in SUSPICIOUS_EXTENSIONS:
                raise ValidationError(f"entry {entry_number} ZIP contains a script/executable member {name!r}")
            mode = (member.external_attr >> 16) & 0o170000
            if mode == 0o120000:
                raise ValidationError(f"entry {entry_number} ZIP contains a symbolic-link member {name!r}")
            if member.file_size > max_member_size:
                raise ValidationError(f"entry {entry_number} ZIP member {name!r} exceeds its size limit")
            total_size += member.file_size
            if total_size > max_total_size:
                raise ValidationError(f"entry {entry_number} ZIP uncompressed size exceeds its total limit")
            compressed = max(member.compress_size, 1)
            if member.file_size / compressed > max_ratio:
                raise ValidationError(f"entry {entry_number} ZIP member {name!r} exceeds compression-ratio limit")
    finally:
        archive.close()


def _hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            while True:
                chunk = handle.read(HASH_CHUNK_SIZE)
                if not chunk:
                    break
                digest.update(chunk)
    except OSError as exc:
        raise ValidationError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def validate(args: argparse.Namespace) -> tuple[int, list[str]]:
    manifest_input = Path(args.manifest).expanduser()
    try:
        _ensure_regular_file(manifest_input, "manifest")
    except ValidationError as exc:
        return 1, [str(exc)]
    manifest = manifest_input.resolve()
    try:
        entries = _load_manifest(manifest, args.max_manifest_size)
    except ValidationError as exc:
        return 1, [str(exc)]

    root_input = Path(args.root).expanduser() if args.root else manifest.parent
    if root_input.is_symlink():
        return 1, [f"asset root must not be a symbolic link: {root_input}"]
    root = root_input.resolve(strict=False)
    if not root.exists() or not root.is_dir():
        return 1, [f"asset root is missing or not a directory: {root}"]

    errors: list[str] = []
    seen: set[Path] = set()
    for number, entry in enumerate(entries, start=1):
        try:
            asset = _validate_relative_asset_path(entry.get("path"), root, manifest)
            if asset in seen:
                raise ValidationError(f"entry {number} duplicates asset path {asset}")
            seen.add(asset)
            extension = _check_extension(asset, entry, number)
            info = _ensure_regular_file(asset, f"asset entry {number}")
            if info.st_size > args.max_file_size:
                raise ValidationError(f"entry {number} exceeds the {args.max_file_size} byte file-size limit")
            expected_size = entry.get("size")
            if expected_size is not None:
                if isinstance(expected_size, bool) or not isinstance(expected_size, int) or expected_size < 0:
                    raise ValidationError(f"entry {number} size must be a non-negative integer")
                if info.st_size != expected_size:
                    raise ValidationError(
                        f"entry {number} size mismatch (manifest {expected_size}, actual {info.st_size})"
                    )
            expected_hash = _validate_digest(entry.get("sha256"), number)
            _check_magic(extension, asset, number, info.st_size)
            if extension == ".zip":
                _check_zip_limits(
                    asset,
                    number,
                    args.max_archive_members,
                    args.max_archive_member_size,
                    args.max_archive_total_size,
                    args.max_compression_ratio,
                )
            actual_hash = _hash_file(asset)
            if actual_hash != expected_hash:
                raise ValidationError(
                    f"entry {number} SHA-256 mismatch (manifest {expected_hash}, actual {actual_hash})"
                )
            print(f"OK  {entry['path']}")
        except (KeyError, TypeError, ValidationError) as exc:
            errors.append(f"FAIL entry {number}: {exc}")

    if errors:
        return 1, errors
    print(f"Validated {len(entries)} asset(s) successfully.")
    return 0, []


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate a JSON asset manifest, hashes, safe formats, and bounded ZIP contents."
    )
    parser.add_argument("manifest", help="manifest JSON file")
    parser.add_argument("--root", help="asset root directory (default: manifest directory)")
    parser.add_argument("--max-manifest-size", type=_positive_int, default=DEFAULT_MAX_MANIFEST_SIZE, metavar="BYTES")
    parser.add_argument("--max-file-size", type=_positive_int, default=DEFAULT_MAX_FILE_SIZE, metavar="BYTES")
    parser.add_argument("--max-archive-members", type=_positive_int, default=DEFAULT_MAX_ARCHIVE_MEMBERS)
    parser.add_argument("--max-archive-member-size", type=_positive_int, default=DEFAULT_MAX_ARCHIVE_MEMBER_SIZE, metavar="BYTES")
    parser.add_argument("--max-archive-total-size", type=_positive_int, default=DEFAULT_MAX_ARCHIVE_TOTAL_SIZE, metavar="BYTES")
    parser.add_argument("--max-compression-ratio", type=_positive_float, default=DEFAULT_MAX_COMPRESSION_RATIO)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    code, errors = validate(args)
    for error in errors:
        print(error, file=sys.stderr)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
