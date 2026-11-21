#!/usr/bin/env python3
"""Local NIST SP 811 check for player-facing text in Out of Spec.

Scans string literals in scripts/**/*.gd, `text = "..."` lines in *.tscn, and
string values in data/*.json (keys starting with "_" and "id" are skipped).
Exits 1 and lists file:line for each violation. Rules: docs/sp811.md.

Run from the repo root:  python tools/check_sp811.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

RULES: list[tuple[str, re.Pattern[str]]] = [
    ("§7.2 space before % (write 80 %)", re.compile(r"\d%(?!%)|%[-+0-9.]*[dfs]%%")),
    ("§7.4/§7.5 no qualifier on % (name relative humidity in the text)", re.compile(r"%%?\s?RH\b")),
    ("§10.5.3 no comma digit grouping (12 000 with U+202F)", re.compile(r"\d,\d{3}(?!\d)")),
    ("§7.2 space between number and unit symbol", re.compile(r"\d(?:ms|mm|cm|km|kg|Hz|kHz|MHz|°C)\b")),
    ("× for multiplication, not x", re.compile(r"\bx\s*MPE|\bx%[.d]|\bx\s?\d+(?:\.\d+)?\b(?!\s*\d)")),
    ("§6.1.8 nonstandard abbreviation", re.compile(r"\b(?:sec|secs|hr|hrs|mins|mps|cc|ppm|ppb|sccm)\b")),
    ("plane-angle ° takes no space", re.compile(r"\d\s+°(?!C)")),
    ("°C needs a space", re.compile(r"\d°C")),
]

GD_STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
TSCN_TEXT = re.compile(r'^\s*text\s*=\s*"((?:[^"\\]|\\.)*)"')


def check_text(text: str) -> list[str]:
    return [name for name, pattern in RULES if pattern.search(text)]


def scan_gd(path: Path) -> list[str]:
    out = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.lstrip().startswith("#"):
            continue
        for m in GD_STRING.finditer(line):
            for rule in check_text(m.group(1)):
                out.append(f"{path.relative_to(ROOT)}:{n}: {rule}: \"{m.group(1)[:60]}\"")
    return out


def scan_tscn(path: Path) -> list[str]:
    out = []
    for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        m = TSCN_TEXT.match(line)
        if m:
            for rule in check_text(m.group(1)):
                out.append(f"{path.relative_to(ROOT)}:{n}: {rule}: \"{m.group(1)[:60]}\"")
    return out


def scan_json(path: Path) -> list[str]:
    out = []
    raw = path.read_text(encoding="utf-8")

    def walk(node, where: str) -> None:
        if isinstance(node, dict):
            for k, v in node.items():
                if k.startswith("_") or k == "id":
                    continue
                walk(v, f"{where}/{k}")
        elif isinstance(node, list):
            for i, v in enumerate(node):
                walk(v, f"{where}[{i}]")
        elif isinstance(node, str):
            for rule in check_text(node):
                out.append(f"{path.relative_to(ROOT)} {where}: {rule}: \"{node[:60]}\"")

    walk(json.loads(raw), "")
    return out


def main() -> int:
    problems: list[str] = []
    for p in sorted(ROOT.glob("scripts/**/*.gd")):
        problems += scan_gd(p)
    for p in sorted(ROOT.glob("**/*.tscn")):
        problems += scan_tscn(p)
    for p in sorted(ROOT.glob("data/*.json")):
        problems += scan_json(p)
    for line in problems:
        print(line)
    print(f"SP 811 check: {len(problems)} problem(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
