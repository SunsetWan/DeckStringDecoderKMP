#!/usr/bin/env python3
"""Generate and validate the immutable BobNoteShared deckstring handoff."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any


DONOR_COMMIT = "af490607cc79c5f28152537a375dd07adf9f099d"
SHA_256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
ACCEPTANCE_MARKER = "deckstring-handoff-acceptance"

BUILD_CONTEXT_PATHS = {
    "build.gradle.kts",
    "deckstring/build.gradle.kts",
    "gradle.properties",
    "gradle/wrapper/gradle-wrapper.jar",
    "gradle/wrapper/gradle-wrapper.properties",
    "gradlew",
    "settings.gradle.kts",
}
FORBIDDEN_RECEIVER_PREFIXES = (
    ".github/",
    "ios_debug_demo/",
    "swiftpm-binary/",
)
BEHAVIOR_CATEGORIES = [
    "model construction and canonical sorting",
    "decode and golden fixtures",
    "encode and canonical output",
    "sideboard parsing and encoding",
    "malformed input and error mapping",
    "numeric boundary validation",
    "Swift Codable, Equatable, and Hashable parity",
    "decode-encode-decode round trip",
]
VERIFICATION_COMMANDS = [
    "./gradlew :deckstring:jvmTest :deckstring:iosSimulatorArm64Test --console=plain",
    "./gradlew :deckstring:prepareDeckStringDecoderSwiftPMBinaryRelease --console=plain",
    "./gradlew :deckstring:verifyDeckStringDecoderSwiftPMConsumer --console=plain",
    "openspec validate --changes --strict --no-interactive",
]


class HandoffError(ValueError):
    """Raised when handoff evidence is incomplete or inconsistent."""


def _run_git(repository: Path, *arguments: str) -> bytes:
    process = subprocess.run(
        ["git", *arguments],
        cwd=repository,
        check=False,
        capture_output=True,
    )
    if process.returncode != 0:
        message = process.stderr.decode("utf-8", errors="replace").strip()
        raise HandoffError(f"git {' '.join(arguments)} failed: {message}")
    return process.stdout


def _ensure_clean_exact_revision(repository: Path, revision: str) -> str:
    if not repository.is_dir():
        raise HandoffError(f"repository does not exist: {repository}")

    status = _run_git(repository, "status", "--porcelain=v1", "--untracked-files=all")
    if status:
        raise HandoffError("source repository must be clean before handoff evidence is read")

    requested_commit = _run_git(repository, "rev-parse", f"{revision}^{{commit}}").decode().strip()
    head_commit = _run_git(repository, "rev-parse", "HEAD").decode().strip()
    if requested_commit != head_commit:
        raise HandoffError(
            f"requested revision {requested_commit} is not the checked-out HEAD {head_commit}"
        )
    return requested_commit


def _category_for_path(path: str) -> str | None:
    if path.startswith("deckstring/src/commonMain/kotlin/"):
        return "production-kotlin"
    if path.startswith("deckstring/src/commonTest/kotlin/"):
        return "common-tests"
    if path.startswith("deckstring/src/commonTest/resources/"):
        return "common-test-resources"
    if path == "deckstring/src/commonMain/swift/DeckStringDecoderFacade.swift":
        return "swift-facade-source"
    if path in BUILD_CONTEXT_PATHS:
        return "build-context"
    return None


def _inventory(repository: Path, commit: str) -> list[dict[str, str]]:
    tree_paths = _run_git(repository, "ls-tree", "-r", "--name-only", commit).decode().splitlines()
    entries: list[dict[str, str]] = []
    for path in sorted(tree_paths):
        category = _category_for_path(path)
        if category is None:
            continue
        blob = _run_git(repository, "show", f"{commit}:{path}")
        entries.append(
            {
                "category": category,
                "path": path,
                "sha256": hashlib.sha256(blob).hexdigest(),
            }
        )
    return entries


def _git_text(repository: Path, commit: str, path: str) -> str:
    return _run_git(repository, "show", f"{commit}:{path}").decode("utf-8")


def _required_match(pattern: str, text: str, name: str) -> str:
    match = re.search(pattern, text, flags=re.MULTILINE)
    if match is None:
        raise HandoffError(f"could not determine {name} from donor build context")
    return match.group(1)


def _toolchain(repository: Path, commit: str) -> dict[str, str]:
    root_build = _git_text(repository, commit, "build.gradle.kts")
    wrapper = _git_text(repository, commit, "gradle/wrapper/gradle-wrapper.properties")
    return {
        "gradle": _required_match(r"gradle-([0-9.]+)-bin\.zip", wrapper, "Gradle version"),
        "gradleDistributionSha256": _required_match(
            r"^distributionSha256Sum=([0-9a-f]{64})$",
            wrapper,
            "Gradle distribution checksum",
        ),
        "kotlin": _required_match(
            r'kotlin\("multiplatform"\)\s+version\s+"([^"]+)"',
            root_build,
            "Kotlin version",
        ),
        "skie": _required_match(
            r'id\("co\.touchlab\.skie"\)\s+version\s+"([^"]+)"',
            root_build,
            "SKIE version",
        ),
    }


def generate_manifest(repository: Path | str, revision: str) -> dict[str, Any]:
    source_repository = Path(repository).resolve()
    commit = _ensure_clean_exact_revision(source_repository, revision)
    remote = _run_git(source_repository, "remote", "get-url", "origin").decode().strip()
    files = _inventory(source_repository, commit)
    if not any(entry["category"] == "production-kotlin" for entry in files):
        raise HandoffError("donor inventory has no production Kotlin source")
    if not any(entry["category"] == "common-tests" for entry in files):
        raise HandoffError("donor inventory has no common tests")
    if not any(entry["category"] == "swift-facade-source" for entry in files):
        raise HandoffError("donor inventory has no Swift facade source")

    return {
        "schemaVersion": 1,
        "repository": {
            "remote": remote,
            "licenseStatus": (
                "The frozen donor tree has no standalone LICENSE file; this is an internal "
                "same-owner product transfer, not a public relicensing grant."
            ),
            "provenance": (
                "Ordinary source snapshot from the immutable donor Git tree; "
                "original history remains in the donor repository."
            ),
        },
        "donorCommit": commit,
        "toolchain": _toolchain(source_repository, commit),
        "behaviorCategories": BEHAVIOR_CATEGORIES,
        "verificationCommands": VERIFICATION_COMMANDS,
        "files": files,
    }


def manifest_bytes(manifest: dict[str, Any]) -> bytes:
    return (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")


def _validate_transfer_path(path: str) -> None:
    pure_path = PurePosixPath(path)
    if pure_path.is_absolute() or ".." in pure_path.parts or "\\" in path:
        raise HandoffError(f"manifest path must be a safe POSIX relative path: {path}")
    if path.startswith(FORBIDDEN_RECEIVER_PREFIXES):
        raise HandoffError(f"manifest contains forbidden receiver input: {path}")
    if _category_for_path(path) is None:
        raise HandoffError(f"manifest contains an out-of-scope receiver input: {path}")


def validate_manifest(repository: Path | str, manifest: dict[str, Any]) -> None:
    source_repository = Path(repository).resolve()
    donor_commit = manifest.get("donorCommit")
    if not isinstance(donor_commit, str) or not COMMIT_PATTERN.fullmatch(donor_commit):
        raise HandoffError("manifest donorCommit must be a full lowercase Git commit")

    expected = generate_manifest(source_repository, donor_commit)
    entries = manifest.get("files")
    if not isinstance(entries, list):
        raise HandoffError("manifest files must be an array")

    actual_paths: list[str] = []
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("path"), str):
            raise HandoffError("every manifest file entry must contain a path")
        path = entry["path"]
        _validate_transfer_path(path)
        actual_paths.append(path)
    if len(actual_paths) != len(set(actual_paths)):
        raise HandoffError("manifest contains duplicate file paths")

    expected_paths = {entry["path"] for entry in expected["files"]}
    actual_path_set = set(actual_paths)
    missing = sorted(expected_paths - actual_path_set)
    extra = sorted(actual_path_set - expected_paths)
    if missing:
        raise HandoffError(f"manifest is missing donor files: {', '.join(missing)}")
    if extra:
        raise HandoffError(f"manifest contains extra donor files: {', '.join(extra)}")
    if actual_paths != sorted(actual_paths):
        raise HandoffError("manifest files are not sorted by path")

    if manifest != expected:
        raise HandoffError("manifest metadata, categories, or Git blob SHA-256 values do not match donor")


def _acceptance_payload(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    pattern = rf"<!--\s*{re.escape(ACCEPTANCE_MARKER)}\s*(\{{.*?\}})\s*-->"
    match = re.search(pattern, text, flags=re.DOTALL)
    if match is None:
        raise HandoffError(f"acceptance file is missing the {ACCEPTANCE_MARKER} JSON block")
    try:
        payload = json.loads(match.group(1))
    except json.JSONDecodeError as error:
        raise HandoffError(f"acceptance JSON is invalid: {error}") from error
    if not isinstance(payload, dict):
        raise HandoffError("acceptance payload must be a JSON object")
    return payload


def _require_string(
    mapping: dict[str, Any],
    field: str,
    pattern: re.Pattern[str] | None = None,
    *,
    label: str | None = None,
) -> str:
    display_name = label or field
    value = mapping.get(field)
    if not isinstance(value, str) or not value.strip():
        raise HandoffError(f"accepted state requires {display_name}")
    if pattern is not None and pattern.fullmatch(value) is None:
        raise HandoffError(f"accepted state has invalid {display_name}")
    return value


def validate_acceptance(path: Path | str) -> dict[str, Any]:
    acceptance_path = Path(path)
    payload = _acceptance_payload(acceptance_path)
    if payload.get("schemaVersion") != 1:
        raise HandoffError("acceptance schemaVersion must be 1")
    donor_commit = payload.get("donorCommit")
    if not isinstance(donor_commit, str) or COMMIT_PATTERN.fullmatch(donor_commit) is None:
        raise HandoffError("acceptance donorCommit must be a full lowercase Git commit")

    status = payload.get("status")
    if status not in {"pending", "accepted"}:
        raise HandoffError("acceptance status must be pending or accepted")
    if status == "pending":
        if payload.get("receiver") is not None or payload.get("bobNoteCompatibilitySet") is not None:
            raise HandoffError("pending acceptance must not contain partial receiver or BobNote evidence")
        return payload

    receiver = payload.get("receiver")
    if not isinstance(receiver, dict):
        raise HandoffError("accepted state requires receiver.commit and receiver evidence")
    _require_string(receiver, "commit", COMMIT_PATTERN, label="receiver.commit")
    _require_string(receiver, "provenanceReport", label="receiver.provenanceReport")
    _require_string(
        receiver,
        "provenanceReportSha256",
        SHA_256_PATTERN,
        label="receiver.provenanceReportSha256",
    )
    _require_string(receiver, "commonTestsEvidence", label="receiver.commonTestsEvidence")
    _require_string(receiver, "nativeTestsEvidence", label="receiver.nativeTestsEvidence")
    _require_string(receiver, "podConsumerEvidence", label="receiver.podConsumerEvidence")

    bob_note = payload.get("bobNoteCompatibilitySet")
    if not isinstance(bob_note, dict):
        raise HandoffError("accepted state requires bobNoteCompatibilitySet.commit")
    _require_string(bob_note, "commit", COMMIT_PATTERN, label="bobNoteCompatibilitySet.commit")
    _require_string(
        bob_note,
        "sharedGitlink",
        COMMIT_PATTERN,
        label="bobNoteCompatibilitySet.sharedGitlink",
    )
    _require_string(
        bob_note,
        "podfileLockSha256",
        SHA_256_PATTERN,
        label="bobNoteCompatibilitySet.podfileLockSha256",
    )
    _require_string(bob_note, "gatesEvidence", label="bobNoteCompatibilitySet.gatesEvidence")
    return payload


def _load_manifest(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise HandoffError(f"could not read manifest {path}: {error}") from error
    if not isinstance(payload, dict):
        raise HandoffError("manifest must be a JSON object")
    return payload


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="area", required=True)

    manifest = subparsers.add_parser("manifest", help="generate or validate donor manifest")
    manifest_subparsers = manifest.add_subparsers(dest="action", required=True)
    generate = manifest_subparsers.add_parser("generate")
    generate.add_argument("--repository", type=Path, required=True)
    generate.add_argument("--revision", default=DONOR_COMMIT)
    generate.add_argument("--output", type=Path, required=True)
    validate = manifest_subparsers.add_parser("validate")
    validate.add_argument("--repository", type=Path, required=True)
    validate.add_argument("--manifest", type=Path, required=True)

    acceptance = subparsers.add_parser("acceptance", help="validate receiver acceptance")
    acceptance_subparsers = acceptance.add_subparsers(dest="action", required=True)
    acceptance_validate = acceptance_subparsers.add_parser("validate")
    acceptance_validate.add_argument("--file", type=Path, required=True)
    return parser


def main(arguments: list[str] | None = None) -> int:
    options = _parser().parse_args(arguments)
    try:
        if options.area == "manifest" and options.action == "generate":
            manifest = generate_manifest(options.repository, options.revision)
            options.output.parent.mkdir(parents=True, exist_ok=True)
            options.output.write_bytes(manifest_bytes(manifest))
            print(f"generated {options.output} from {manifest['donorCommit']}")
        elif options.area == "manifest" and options.action == "validate":
            validate_manifest(options.repository, _load_manifest(options.manifest))
            print(f"validated {options.manifest}")
        elif options.area == "acceptance" and options.action == "validate":
            payload = validate_acceptance(options.file)
            print(f"validated {options.file} ({payload['status']})")
        else:
            raise AssertionError("unreachable command")
    except HandoffError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
