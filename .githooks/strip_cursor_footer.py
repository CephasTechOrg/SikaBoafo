"""Remove IDE-injected Cursor attribution lines from a git commit message file."""
from __future__ import annotations

import pathlib
import re
import sys

# Footers like "Made-with: Cursor", "Made by: Cursor", "Co-authored-by: … Cursor"
_LINE = re.compile(
    r"(?i)^\s*("
    r"made[-\s]+(?:with|by)\s*:.+\bcursor\b"
    r"|co-authored-by\s*:.+\bcursor\b"
    r")\s*$"
)


def strip_message(text: str) -> str:
    out: list[str] = []
    for line in text.splitlines(True):
        core = line.replace("\r", "").rstrip("\n")
        if _LINE.match(core):
            continue
        out.append(line)
    return "".join(out)


def main() -> None:
    path = pathlib.Path(sys.argv[1])
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError:
        raise SystemExit(0)
    stripped = strip_message(raw)
    if stripped != raw:
        path.write_text(stripped, encoding="utf-8")


if __name__ == "__main__":
    main()
