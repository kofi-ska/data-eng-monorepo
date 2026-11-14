#!/usr/bin/env python3
"""Plan or deploy the Finance Analytics Lakehouse."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.request
from pathlib import Path


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(command))
    return subprocess.run(command, check=True, text=True, capture_output=capture)


def current_public_ip() -> str:
    request = urllib.request.Request(
        "https://api.ipify.org", headers={"User-Agent": "finance-lakehouse/1.0"}
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read().decode("ascii").strip()


def terraform_outputs(terraform_dir: Path) -> dict[str, str]:
    result = run(
        ["terraform", f"-chdir={terraform_dir}", "output", "-json"], capture=True
    )
    values = json.loads(result.stdout)
    return {name: item["value"] for name, item in values.items()}


def main() -> int:
    project_dir = Path(__file__).resolve().parent.parent
    terraform_dir = project_dir / "infra" / "azure"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("plan", "apply"))
    parser.add_argument("--subscription-id", required=True)
    parser.add_argument("--client-ip")
    parser.add_argument("--skip-download", action="store_true")
    args = parser.parse_args()

    account = json.loads(
        run(["az", "account", "show", "--output", "json"], capture=True).stdout
    )
    if account["id"] != args.subscription_id:
        print(
            f"ERROR: active subscription is {account['id']}, expected {args.subscription_id}",
            file=sys.stderr,
        )
        return 2

    client_ip = args.client_ip or current_public_ip()
    run(["terraform", f"-chdir={terraform_dir}", "init"])
    plan_path = terraform_dir / "finance-lakehouse.tfplan"
    run(
        [
            "terraform",
            f"-chdir={terraform_dir}",
            "plan",
            "-out",
            str(plan_path),
            f"-var=subscription_id={args.subscription_id}",
            f"-var=client_ip={client_ip}",
        ]
    )
    if args.action == "plan":
        print(f"Plan written to {plan_path}")
        return 0

    run(["terraform", f"-chdir={terraform_dir}", "apply", str(plan_path)])
    if not args.skip_download:
        run([sys.executable, str(project_dir / "src" / "download_eba_data.py")])
    run([sys.executable, str(project_dir / "src" / "upload_raw_to_blob.py")])

    outputs = terraform_outputs(terraform_dir)
    run(
        [
            sys.executable,
            str(project_dir / "src" / "render_sql.py"),
            "--storage-account",
            outputs["storage_account_name"],
        ]
    )
    print("Infrastructure and raw ingestion completed.")
    print("Run build/sql against:", outputs["serverless_sql_endpoint"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
