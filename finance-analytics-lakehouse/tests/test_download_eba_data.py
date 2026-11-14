import hashlib
import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from download_eba_data import build_manifest_entry, download_file, sha256_file


class DownloadEbaDataTests(unittest.TestCase):
    def test_sha256_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.csv"
            content = b"item,amount\n2520102,100.0\n"
            path.write_bytes(content)

            self.assertEqual(sha256_file(path), hashlib.sha256(content).hexdigest())

    def test_download_file_replaces_partial_file_atomically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.csv"
            destination = root / "destination.csv"
            source.write_bytes(b"official EBA data")

            download_file(source.as_uri(), destination)

            self.assertEqual(destination.read_bytes(), b"official EBA data")
            self.assertFalse((root / "destination.csv.part").exists())

    def test_manifest_entry_contains_lineage_controls(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tr_oth.csv"
            path.write_bytes(b"content")

            entry = build_manifest_entry(path, "https://example.test/tr_oth.csv")

            self.assertEqual(entry["file_name"], "tr_oth.csv")
            self.assertEqual(entry["size_bytes"], 7)
            self.assertEqual(entry["sha256"], sha256_file(path))
            self.assertEqual(entry["source_url"], "https://example.test/tr_oth.csv")


if __name__ == "__main__":
    unittest.main()
