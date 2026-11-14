#!/usr/bin/env python3
"""Download the official EBA 2025 transparency source package."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


BASE_URL = "https://www.eba.europa.eu/assets/TE2025/Full_database/883401"
SOURCE_FILES = (
    "tr_oth.csv",
    "tr_cre.csv",
    "SDD.xlsx",
    "TR_Metadata.xlsx",
    "2025_EU-wide_Transparency_exercise_Mapped_templates.xlsx",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download_file(url: str, destination: Path) -> None:
    partial = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": "finance-lakehouse/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            with partial.open("wb") as output:
                shutil.copyfileobj(response, output)
        partial.replace(destination)
    except Exception:
        partial.unlink(missing_ok=True)
        raise


def build_manifest_entry(path: Path, source_url: str) -> dict[str, object]:
    return {
        "file_name": path.name,
        "source_url": source_url,
        "size_bytes": path.stat().st_size,
        "sha256": sha256_file(path),
    }


def parse_arguments() -> argparse.Namespace:
    project_dir = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=project_dir / "data" / "raw" / "eba" / "2025",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Download files again even when they already exist.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    output_dir = arguments.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    entries: list[dict[str, object]] = []
    for file_name in SOURCE_FILES:
        source_url = f"{BASE_URL}/{file_name}"
        destination = output_dir / file_name
        if destination.exists() and not arguments.force:
            print(f"EXISTS: {destination.name}")
        else:
            print(f"DOWNLOAD: {source_url}")
            try:
                download_file(source_url, destination)
            except Exception as error:
                print(f"ERROR: Could not download {source_url}: {error}", file=sys.stderr)
                return 1
        entries.append(build_manifest_entry(destination, source_url))

    manifest = {
        "source": "European Banking Authority 2025 EU-wide Transparency Exercise",
        "publication_id": "TE2025/883401",
        "downloaded_at_utc": datetime.now(timezone.utc).isoformat(),
        "files": entries,
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"MANIFEST: {manifest_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
