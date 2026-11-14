#!/usr/bin/env python3
"""Upload staged EBA source files to Terraform-managed Azure Blob Storage.

The script is intentionally non-provisioning. If the local files, Terraform
outputs, storage account, or container are unavailable, it reports a skip and
exits successfully without creating anything.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen


def skip(reason: str) -> int:
    print(f"SKIP: {reason}")
    return 0


def run_command(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        arguments,
        check=False,
        capture_output=True,
        text=True,
    )


def terraform_output(terraform_dir: Path, name: str) -> str | None:
    result = run_command(
        [
            "terraform",
            f"-chdir={terraform_dir}",
            "output",
            "-raw",
            name,
        ]
    )
    if result.returncode != 0:
        return None
    value = result.stdout.strip()
    return value or None


def storage_account_exists(storage_account_name: str) -> bool:
    result = run_command(
        [
            "az",
            "storage",
            "account",
            "show",
            "--name",
            storage_account_name,
            "--output",
            "none",
        ]
    )
    return result.returncode == 0


def container_exists(storage_account_name: str, container_name: str) -> bool:
    result = run_command(
        [
            "az",
            "storage",
            "container",
            "exists",
            "--account-name",
            storage_account_name,
            "--name",
            container_name,
            "--auth-mode",
            "login",
            "--query",
            "exists",
            "--output",
            "tsv",
        ]
    )
    return result.returncode == 0 and result.stdout.strip().lower() == "true"


def upload_files(
    source_dir: Path,
    source_files: list[Path],
    storage_account_name: str,
    container_name: str,
    destination_path: str,
) -> int:
    token_result = run_command(
        [
            "az",
            "account",
            "get-access-token",
            "--resource",
            "https://storage.azure.com/",
            "--output",
            "json",
        ]
    )
    if token_result.returncode != 0:
        print(token_result.stderr, file=sys.stderr)
        return token_result.returncode

    access_token = json.loads(token_result.stdout)["accessToken"]
    missing: list[Path] = []
    for path in source_files:
        blob_name = f"{destination_path}/{path.relative_to(source_dir).as_posix()}"
        blob_url = (
            f"https://{storage_account_name}.blob.core.windows.net/"
            f"{container_name}/{quote(blob_name)}"
        )
        request = Request(
            blob_url,
            method="HEAD",
            headers={
                "Authorization": f"Bearer {access_token}",
                "x-ms-version": "2023-11-03",
            },
        )
        try:
            with urlopen(request):
                continue
        except HTTPError as error:
            if error.code != 404:
                print(f"Blob check failed for {blob_name}: HTTP {error.code}")
                return 1
            missing.append(path)

    if not missing:
        print("No upload required; all source blobs already exist.")
        return 0

    for path in missing:
        blob_name = f"{destination_path}/{path.relative_to(source_dir).as_posix()}"
        result = subprocess.run(
            [
                "az",
                "storage",
                "blob",
                "upload",
                "--account-name",
                storage_account_name,
                "--container-name",
                container_name,
                "--name",
                blob_name,
                "--file",
                str(path),
                "--auth-mode",
                "login",
                "--overwrite",
                "false",
                "--output",
                "none",
            ],
            check=False,
        )
        if result.returncode != 0:
            return result.returncode
        print(f"UPLOADED: {blob_name}")
    return 0


def parse_arguments() -> argparse.Namespace:
    project_dir = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(
        description="Upload staged EBA files to existing Terraform-managed storage."
    )
    parser.add_argument(
        "--source-dir",
        type=Path,
        default=project_dir / "data" / "raw" / "eba" / "2025",
    )
    parser.add_argument(
        "--terraform-dir",
        type=Path,
        default=project_dir / "infra" / "azure",
    )
    parser.add_argument(
        "--destination-path",
        default="eba/transparency-exercise/2025",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    source_dir = arguments.source_dir.resolve()
    terraform_dir = arguments.terraform_dir.resolve()

    if shutil.which("az") is None:
        return skip("Azure CLI is not installed.")
    if shutil.which("terraform") is None:
        return skip("Terraform is not installed.")
    if not source_dir.is_dir():
        return skip(f"Source directory does not exist: {source_dir}")

    source_files = [
        path
        for path in source_dir.rglob("*")
        if path.is_file() and not path.name.startswith(".")
    ]
    if not source_files:
        return skip(f"Source directory is empty: {source_dir}")
    if not (terraform_dir / ".terraform").is_dir():
        return skip(f"Terraform has not been initialised in {terraform_dir}.")

    storage_account_name = terraform_output(terraform_dir, "storage_account_name")
    if storage_account_name is None:
        return skip("Terraform output storage_account_name is unavailable.")

    raw_container_name = terraform_output(terraform_dir, "raw_container_name")
    if raw_container_name is None:
        return skip("Terraform output raw_container_name is unavailable.")

    if not storage_account_exists(storage_account_name):
        return skip(
            "Storage account does not exist or is not accessible: "
            f"{storage_account_name}"
        )
    if not container_exists(storage_account_name, raw_container_name):
        return skip(
            "Blob container does not exist or is not accessible: "
            f"{raw_container_name}"
        )

    print(
        f"Uploading {len(source_files)} source files to "
        f"{storage_account_name}/{raw_container_name}/"
        f"{arguments.destination_path}"
    )
    return upload_files(
        source_dir,
        source_files,
        storage_account_name,
        raw_container_name,
        arguments.destination_path,
    )


if __name__ == "__main__":
    sys.exit(main())
