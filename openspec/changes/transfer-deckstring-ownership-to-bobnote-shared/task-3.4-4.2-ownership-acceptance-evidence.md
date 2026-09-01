# Tasks 3.4 through 4.2 ownership acceptance evidence

Recorded: 2026-09-01 (Asia/Shanghai)

`python3 -B scripts/deckstring_handoff.py acceptance validate --file handoff/bobnote-shared/receiver-acceptance.md` accepted the complete machine block. It binds:

- donor commit `af490607cc79c5f28152537a375dd07adf9f099d`;
- Shared final evidence commit `2642442f485d784d1efd6c8d2cbc788be442b58d` and Bob-consumed gitlink `4a14ecf03d6b9c2069c1b39e73f1df34cb825aca`;
- BobNote acceptance commit `ad959b63f7770c80c3fb03138cdf0f09bf2db567` (product source commit `92aa0f6b8e200a327b00d127175f7d1d49994bc2`);
- BobNote `Podfile.lock` SHA-256 `002fffbce40932baee7c817a656a08260139256518767efa5885c9e07c8a0f91` and full App gates evidence.

Root README and the handoff README now name `BobNoteSharedKMP` as BobNote's sole product owner. They describe `0.1.0-kmp.5` only as historical/whole-input rollback evidence and reject a parallel BobNote release line. `rg` found no live maintainer text claiming this donor remains BobNote's current implementation owner; remaining `pending` wording is explicitly historical baseline/state-machine/design text.

The current worktree diff contains no change under `.github/`, `deckstring/`, `gradle/`, `ios_debug_demo/`, or `swiftpm-binary/`, and no root Gradle/wrapper input changed. Git history was not rewritten. The donor remote remains unarchived; its source remote currently exposes `main` and `codex/bobnote-integration`, while the public wrapper still resolves tag `0.1.0-kmp.5` to `2476e1adbcdd1a3a5028ffc639fe67da6b989b44`. No tag, release, branch, remote archive, push, source, demo, or CI deletion was performed.
