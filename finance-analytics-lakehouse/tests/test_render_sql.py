import sys
import tempfile
import unittest
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT / "src"))

from render_sql import PLACEHOLDER, render_sql_tree


class RenderSqlTests(unittest.TestCase):
    def test_replaces_storage_account_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            output = root / "output"
            source.mkdir()
            (source / "view.sql").write_text(
                f"SELECT '{PLACEHOLDER}';\n", encoding="utf-8"
            )

            rendered = render_sql_tree(source, output, "stfinance123")

            self.assertEqual(rendered, [output / "view.sql"])
            self.assertEqual(
                (output / "view.sql").read_text(encoding="utf-8"),
                "SELECT 'stfinance123';\n",
            )


if __name__ == "__main__":
    unittest.main()
