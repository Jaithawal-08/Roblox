#!/usr/bin/env python3
"""Inspect Roblox ``.rbxmx`` XML without executing any model content.

The scanner reports embedded Script, LocalScript, and ModuleScript instances,
then checks their Source properties for common Roblox backdoor and obfuscation
indicators. It intentionally reports indicators rather than trying to prove
that code is malicious: a model containing scripts with no indicator receives a
REVIEW verdict, while a model with a high-confidence indicator receives a
SUSPICIOUS verdict.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


DEFAULT_MAX_BYTES = 64 * 1024 * 1024
MAX_ELEMENTS = 250_000
MAX_SCRIPTS = 25_000

SCRIPT_CLASSES = frozenset({"script", "localscript", "modulescript"})

# Pattern names are intentionally stable so CI/report consumers can suppress or
# audit a finding without relying on a source-code snippet.
PATTERNS: tuple[tuple[str, str, str, re.Pattern[str]], ...] = (
    (
        "external_require_id",
        "high",
        "require() loads a numeric asset/module id",
        re.compile(r"\brequire\s*\(\s*\d{4,}\s*\)", re.IGNORECASE),
    ),
    (
        "dynamic_require",
        "high",
        "require() is combined with a dynamic/remote module expression",
        re.compile(r"\brequire\s*\(\s*(?:game\s*[:.]|workspace\s*[:.]|_G\s*\[)", re.IGNORECASE),
    ),
    (
        "dynamic_code_execution",
        "high",
        "dynamic code execution primitive (loadstring/load) detected",
        re.compile(r"\b(?:loadstring|load)\s*\(", re.IGNORECASE),
    ),
    (
        "http_request",
        "high",
        "HTTP/network request API detected",
        re.compile(
            r"(?:\bHttpService\b|\b(?:HttpGet|HttpPost|GetAsync|PostAsync|RequestAsync)\b|\b(?:syn\.)?request\s*\()",
            re.IGNORECASE,
        ),
    ),
    (
        "asset_insertion",
        "high",
        "runtime asset insertion/loading API detected",
        re.compile(r"\b(?:InsertService|AssetService)\b.{0,160}\b(?:LoadAsset|LoadLocalAsset)\s*\(", re.IGNORECASE | re.DOTALL),
    ),
    (
        "environment_access",
        "high",
        "unsafe environment/global access primitive detected",
        re.compile(r"\b(?:getfenv|setfenv|getgenv)\s*\(|\bdebug\s*\.\s*(?:getinfo|setmetatable)", re.IGNORECASE),
    ),
    (
        "server_script_injection",
        "high",
        "script is assigned into a server container at runtime",
        re.compile(
            r"(?:Parent\s*=\s*game\s*:\s*GetService\s*\(\s*[\"']ServerScriptService|ServerScriptService\s*[:.]\s*[A-Za-z_])",
            re.IGNORECASE,
        ),
    ),
    (
        "encoded_character_builder",
        "medium",
        "character-code construction often used by obfuscators",
        re.compile(r"\b(?:string|utf8)\s*\.\s*char\s*\(", re.IGNORECASE),
    ),
    (
        "encoded_transform",
        "medium",
        "encoded/reversible transform often used by obfuscators",
        re.compile(r"\b(?:bit32\s*\.\s*bxor|string\s*\.\s*reverse|base64|fromCharCode)\b", re.IGNORECASE),
    ),
    (
        "escaped_payload",
        "medium",
        "long escaped or encoded payload detected",
        re.compile(r"(?:\\x[0-9a-f]{2}){8,}|(?:\\[0-9]{3}){8,}|[A-Za-z0-9+/]{200,}={0,2}", re.IGNORECASE),
    ),
)


class ScanError(Exception):
    """A safe scanner input/check failure."""


def _positive_int(value: str) -> int:
    try:
        parsed = int(value, 10)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("must be an integer") from exc
    if parsed <= 0:
        raise argparse.ArgumentTypeError("must be greater than zero")
    return parsed


def _safe_label(value: object, fallback: str) -> str:
    if not isinstance(value, str) or not value:
        return fallback
    cleaned = "".join(char if char.isprintable() and char not in "\r\n\t" else "?" for char in value)
    return cleaned[:120] or fallback


def _local_name(tag: object) -> str:
    if not isinstance(tag, str):
        return ""
    return tag.rsplit("}", 1)[-1].lower()


def _read_model(path: Path, max_bytes: int) -> bytes:
    try:
        info = path.lstat()
    except OSError as exc:
        raise ScanError(f"missing model: {exc}") from exc
    if path.is_symlink():
        raise ScanError("model must not be a symbolic link")
    if not path.is_file():
        raise ScanError("model is not a regular file")
    if info.st_size > max_bytes:
        raise ScanError(f"model exceeds the {max_bytes} byte limit")
    try:
        data = path.read_bytes()
    except OSError as exc:
        raise ScanError(f"cannot read model: {exc}") from exc
    if len(data) > max_bytes:
        raise ScanError(f"model exceeds the {max_bytes} byte limit")
    if b"\x00" in data:
        raise ScanError("model contains NUL bytes and is not text XML")
    if re.search(rb"<!\s*(?:DOCTYPE|ENTITY)\b", data, re.IGNORECASE):
        raise ScanError("model contains a DTD/entity declaration; refusing unsafe XML constructs")
    if data.startswith((b"PK\x03\x04", b"MZ", b"\x7fELF")):
        raise ScanError("model has an archive/executable signature, not plain .rbxmx XML")
    return data


def _parse_model(data: bytes) -> ET.Element:
    try:
        text = data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise ScanError(f"model is not UTF-8 XML: {exc}") from exc
    try:
        root = ET.fromstring(text)
    except ET.ParseError as exc:
        raise ScanError(f"model is not well-formed XML: {exc}") from exc
    if _local_name(root.tag) != "roblox":
        raise ScanError("XML root is not <roblox>")
    elements = 0
    for _ in root.iter():
        elements += 1
        if elements > MAX_ELEMENTS:
            raise ScanError(f"model contains more than {MAX_ELEMENTS} XML elements")
    return root


def _property_text(item: ET.Element, property_name: str) -> str:
    for element in item.iter():
        if _local_name(element.tag) in {"string", "protectedstring", "sharedstring"} and element.attrib.get("name", "").lower() == property_name.lower():
            return element.text or ""
    return ""


def _item_path(item: ET.Element, ancestors: list[str]) -> str:
    name = _safe_label(_property_text(item, "Name"), "<unnamed>")
    class_name = _safe_label(item.attrib.get("class"), "Item")
    pieces = [*ancestors, f"{name} ({class_name})"]
    return "/".join(pieces)


def _find_scripts(root: ET.Element) -> list[tuple[ET.Element, str]]:
    scripts: list[tuple[ET.Element, str]] = []
    pending: list[tuple[ET.Element, list[str]]] = [(root, [])]
    while pending:
        node, ancestors = pending.pop()
        if _local_name(node.tag) == "item":
            class_name = node.attrib.get("class", "").lower()
            if class_name in SCRIPT_CLASSES:
                scripts.append((node, _item_path(node, ancestors)))
                if len(scripts) > MAX_SCRIPTS:
                    raise ScanError(f"model contains more than {MAX_SCRIPTS} script instances")
            next_ancestors = [*ancestors, _safe_label(_property_text(node, "Name"), "<unnamed>")]
        else:
            next_ancestors = ancestors
        for child in reversed(list(node)):
            pending.append((child, next_ancestors))
    return scripts


def _script_findings(source: str) -> list[dict[str, object]]:
    findings: list[dict[str, object]] = []
    for name, severity, message, pattern in PATTERNS:
        matches = list(pattern.finditer(source))
        if matches:
            findings.append(
                {
                    "id": name,
                    "severity": severity,
                    "message": message,
                    "matches": len(matches),
                }
            )
    long_lines = max((len(line) for line in source.splitlines()), default=0)
    if long_lines > 4_000:
        findings.append(
            {
                "id": "very_long_line",
                "severity": "medium",
                "message": "source contains an unusually long line, a possible packed payload",
                "matches": 1,
            }
        )
    return findings


def scan(path: Path, max_bytes: int, fail_on_scripts: bool) -> dict[str, object]:
    result: dict[str, object] = {"path": str(path), "scripts": [], "findings": []}
    if path.suffix.lower() != ".rbxmx":
        raise ScanError("input must have a .rbxmx extension")
    data = _read_model(path, max_bytes)
    root = _parse_model(data)
    scripts = _find_scripts(root)
    script_reports: list[dict[str, object]] = []
    all_findings: list[dict[str, object]] = []
    for index, (item, item_path) in enumerate(scripts, start=1):
        source = _property_text(item, "Source")
        script_findings = _script_findings(source)
        report = {
            "index": index,
            "class": _safe_label(item.attrib.get("class"), "Script"),
            "name": _safe_label(_property_text(item, "Name"), "<unnamed>"),
            "path": item_path,
            "source_bytes": len(source.encode("utf-8")),
            "source_sha256": hashlib.sha256(source.encode("utf-8")).hexdigest(),
            "findings": script_findings,
        }
        script_reports.append(report)
        for finding in script_findings:
            all_findings.append({"script_index": index, **finding})

    result["scripts"] = script_reports
    result["findings"] = all_findings
    result["script_count"] = len(script_reports)
    result["finding_count"] = len(all_findings)
    if all_findings:
        result["verdict"] = "SUSPICIOUS"
    elif script_reports:
        result["verdict"] = "REVIEW" if not fail_on_scripts else "SUSPICIOUS"
    else:
        result["verdict"] = "SAFE"
    return result


def _print_report(report: dict[str, object]) -> None:
    print(f"Model: {report['path']}")
    print(f"Verdict: {report['verdict']}")
    print(f"Scripts: {report['script_count']}; indicators: {report['finding_count']}")
    for script in report["scripts"]:
        print(f"  {script['class']} {script['path']} ({script['source_bytes']} source bytes)")
        for finding in script["findings"]:
            print(f"    [{finding['severity']}] {finding['id']}: {finding['message']} ({finding['matches']} match(es))")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Safely scan .rbxmx XML for embedded scripts, Roblox backdoor patterns, and obfuscation indicators."
    )
    parser.add_argument("models", nargs="+", help="one or more .rbxmx files to inspect")
    parser.add_argument("--max-bytes", type=_positive_int, default=DEFAULT_MAX_BYTES, metavar="BYTES", help="maximum model size (default: 64 MiB)")
    parser.add_argument("--fail-on-scripts", action="store_true", help="return failure for any embedded script, even without indicators")
    parser.add_argument("--json", action="store_true", dest="as_json", help="emit JSON reports instead of human-readable reports")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    reports: list[dict[str, object]] = []
    had_error = False
    for raw_path in args.models:
        path = Path(raw_path).expanduser()
        try:
            reports.append(scan(path, args.max_bytes, args.fail_on_scripts))
        except ScanError as exc:
            had_error = True
            reports.append({"path": str(path), "verdict": "INVALID", "error": str(exc), "scripts": [], "findings": []})

    if args.as_json:
        print(json.dumps(reports, indent=2, sort_keys=True))
    else:
        for index, report in enumerate(reports):
            if index:
                print()
            if report["verdict"] == "INVALID":
                print(f"Model: {report['path']}\nVerdict: INVALID\nError: {report['error']}")
            else:
                _print_report(report)

    if had_error:
        return 2
    if any(report["verdict"] == "SUSPICIOUS" for report in reports):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
