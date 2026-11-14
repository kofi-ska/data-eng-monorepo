#!/usr/bin/env python3
"""Render deployable SQL with the Terraform-created storage account name."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path


PLACEHOLDER = "<storage-account-name>"


def render_sql_tree(source_dir: Path, output_dir: Path, storage_account: str) -> list[Path]:
    rendered: list[Path] = []
    if output_dir.exists():
        shutil.rmtree(output_dir)
    for source in sorted(source_dir.rglob("*.sql")):
        destination = output_dir / source.relative_to(source_dir)
        destination.parent.mkdir(parents=True, exist_ok=True)
        text = source.read_text(encoding="utf-8").replace(PLACEHOLDER, storage_account)
        destination.write_text(text, encoding="utf-8")
        rendered.append(destination)
    return rendered


def main() -> int:
    project_dir = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--storage-account", required=True)
    parser.add_argument("--output-dir", type=Path, default=project_dir / "build" / "sql")
    args = parser.parse_args()
    files = render_sql_tree(project_dir / "src" / "sql", args.output_dir, args.storage_account)
    print(f"Rendered {len(files)} SQL files to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
