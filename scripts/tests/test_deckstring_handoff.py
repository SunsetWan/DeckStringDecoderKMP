from __future__ import annotations

import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_DIRECTORY = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPTS_DIRECTORY))

from deckstring_handoff import (  # noqa: E402
    HandoffError,
    generate_manifest,
    manifest_bytes,
    validate_acceptance,
    validate_manifest,
)


class DeckStringHandoffTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repository = Path(self.temporary_directory.name) / "donor"
        self.repository.mkdir()

        self._git("init", "--initial-branch=main")
        self._git("config", "user.email", "tests@example.com")
        self._git("config", "user.name", "Handoff Tests")
        self._git("config", "commit.gpgsign", "false")
        self._git(
            "remote",
            "add",
            "origin",
            "git@github.com:SunsetWan/DeckStringDecoderKMP.git",
        )

        files = {
            "build.gradle.kts": (
                'plugins {\n'
                '    kotlin("multiplatform") version "2.3.20" apply false\n'
                '    id("co.touchlab.skie") version "0.10.11" apply false\n'
                '}\n'
            ),
            "settings.gradle.kts": 'include(":deckstring")\n',
            "gradle.properties": "kotlin.code.style=official\n",
            "gradle/wrapper/gradle-wrapper.properties": (
                "distributionUrl=https\\://services.gradle.org/distributions/"
                "gradle-9.3.0-bin.zip\n"
                "distributionSha256Sum=" + ("a" * 64) + "\n"
            ),
            "gradle/wrapper/gradle-wrapper.jar": b"wrapper fixture\n",
            "gradlew": "#!/bin/sh\n",
            "deckstring/build.gradle.kts": "plugins { kotlin(\"multiplatform\") }\n",
            "deckstring/src/commonMain/kotlin/example/Deck.kt": "data class Deck(val id: Int)\n",
            "deckstring/src/commonMain/kotlin/example/Codec.kt": "object Codec\n",
            "deckstring/src/commonMain/swift/DeckStringDecoderFacade.swift": (
                "public struct DeckStringDecoder {}\n"
            ),
            "deckstring/src/commonTest/kotlin/example/DeckTest.kt": "class DeckTest\n",
            "deckstring/src/commonTest/resources/golden.txt": "fixture\n",
        }
        for relative_path, contents in files.items():
            destination = self.repository / relative_path
            destination.parent.mkdir(parents=True, exist_ok=True)
            if isinstance(contents, bytes):
                destination.write_bytes(contents)
            else:
                destination.write_text(contents, encoding="utf-8")

        self._git("add", ".")
        self._git("commit", "-m", "fixture")
        self.commit = self._git("rev-parse", "HEAD").stdout.strip()

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def test_generates_from_the_exact_clean_commit_with_stable_sorted_bytes(self) -> None:
        first = generate_manifest(self.repository, self.commit)
        second = generate_manifest(self.repository, self.commit)

        self.assertEqual(first["donorCommit"], self.commit)
        self.assertEqual(manifest_bytes(first), manifest_bytes(second))
        paths = [entry["path"] for entry in first["files"]]
        self.assertEqual(paths, sorted(paths))

        source_path = "deckstring/src/commonMain/kotlin/example/Deck.kt"
        source_entry = next(entry for entry in first["files"] if entry["path"] == source_path)
        blob = self._git("show", f"{self.commit}:{source_path}", text=False).stdout
        self.assertEqual(source_entry["sha256"], hashlib.sha256(blob).hexdigest())
        validate_manifest(self.repository, first)

    def test_rejects_a_revision_that_is_not_the_checked_out_commit(self) -> None:
        self._write("README.md", "second commit\n")
        self._git("add", "README.md")
        self._git("commit", "-m", "second")

        with self.assertRaisesRegex(HandoffError, "checked-out HEAD"):
            generate_manifest(self.repository, self.commit)

    def test_rejects_a_dirty_source_repository(self) -> None:
        self._write("deckstring/src/commonMain/kotlin/example/Deck.kt", "dirty\n")

        with self.assertRaisesRegex(HandoffError, "clean"):
            generate_manifest(self.repository, self.commit)

    def test_validator_rejects_missing_and_extra_files(self) -> None:
        manifest = generate_manifest(self.repository, self.commit)

        missing = copy.deepcopy(manifest)
        missing["files"].pop()
        with self.assertRaisesRegex(HandoffError, "missing"):
            validate_manifest(self.repository, missing)

        extra = copy.deepcopy(manifest)
        extra["files"].append(
            {
                "category": "production-kotlin",
                "path": "deckstring/src/commonMain/kotlin/example/Extra.kt",
                "sha256": "0" * 64,
            }
        )
        with self.assertRaisesRegex(HandoffError, "extra"):
            validate_manifest(self.repository, extra)

    def test_pending_acceptance_is_valid(self) -> None:
        acceptance = self.repository.parent / "pending.md"
        self._write_acceptance(
            acceptance,
            {
                "schemaVersion": 1,
                "status": "pending",
                "donorCommit": self.commit,
                "receiver": None,
                "bobNoteCompatibilitySet": None,
            },
        )

        validate_acceptance(acceptance)

    def test_accepted_state_requires_receiver_and_bobnote_evidence(self) -> None:
        complete = {
            "schemaVersion": 1,
            "status": "accepted",
            "donorCommit": self.commit,
            "receiver": {
                "commit": "1" * 40,
                "provenanceReport": "docs/deckstring-donor-adaptation.md",
                "provenanceReportSha256": "2" * 64,
                "commonTestsEvidence": "JVM and iOS common tests passed",
                "nativeTestsEvidence": "Kotlin Native bridge tests passed",
                "podConsumerEvidence": "Swift overlay Pod consumer passed",
            },
            "bobNoteCompatibilitySet": {
                "commit": "3" * 40,
                "sharedGitlink": "1" * 40,
                "podfileLockSha256": "4" * 64,
                "gatesEvidence": "BobNote compatibility gates passed",
            },
        }

        cases = [
            ("receiver.commit", ("receiver", "commit")),
            ("receiver.podConsumerEvidence", ("receiver", "podConsumerEvidence")),
            ("bobNoteCompatibilitySet.commit", ("bobNoteCompatibilitySet",)),
        ]
        for expected_error, path in cases:
            with self.subTest(expected_error=expected_error):
                payload = copy.deepcopy(complete)
                if len(path) == 1:
                    payload[path[0]] = None
                else:
                    payload[path[0]][path[1]] = None
                acceptance = self.repository.parent / f"invalid-{path[-1]}.md"
                self._write_acceptance(acceptance, payload)
                with self.assertRaisesRegex(HandoffError, expected_error):
                    validate_acceptance(acceptance)

        acceptance = self.repository.parent / "complete-accepted.md"
        self._write_acceptance(acceptance, complete)
        validate_acceptance(acceptance)

    def _git(self, *arguments: str, text: bool = True) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.repository,
            check=True,
            capture_output=True,
            text=text,
        )

    def _write(self, relative_path: str, contents: str) -> None:
        destination = self.repository / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8")

    @staticmethod
    def _write_acceptance(path: Path, payload: dict[str, object]) -> None:
        path.write_text(
            "# Receiver acceptance\n\n"
            "<!-- deckstring-handoff-acceptance\n"
            + json.dumps(payload, indent=2, sort_keys=True)
            + "\n-->\n",
            encoding="utf-8",
        )


if __name__ == "__main__":
    unittest.main()
