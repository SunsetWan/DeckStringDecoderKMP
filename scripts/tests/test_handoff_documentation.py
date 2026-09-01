from __future__ import annotations

import re
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[2]
HANDOFF_DIRECTORY = REPOSITORY / "handoff" / "bobnote-shared"
MARKDOWN_LINK_PATTERN = re.compile(r"\[[^\]]+\]\(([^)]+)\)")


class HandoffDocumentationTestCase(unittest.TestCase):
    def test_every_relative_markdown_link_resolves(self) -> None:
        checked_links = 0
        for document in sorted(HANDOFF_DIRECTORY.glob("*.md")):
            for target in MARKDOWN_LINK_PATTERN.findall(
                document.read_text(encoding="utf-8")
            ):
                if "://" in target or target.startswith("#"):
                    continue
                relative_target = target.split("#", maxsplit=1)[0]
                self.assertFalse(Path(relative_target).is_absolute(), target)
                resolved = (document.parent / relative_target).resolve()
                self.assertTrue(resolved.exists(), f"{document}: missing {target}")
                checked_links += 1

        self.assertGreater(checked_links, 0)


if __name__ == "__main__":
    unittest.main()
