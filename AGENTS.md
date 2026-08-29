# RaidThreeBags Project Governance

Global rules are inherited from `/opt/data/SOUL.md`.

## Project

- RaidThreeBags is a standalone World of Warcraft: Wrath of the Lich King 3.3.5a addon targeting Interface `30300` and Lua 5.1-era APIs.
- The repository root is authoritative for the GitHub/Warperia distribution candidate; resolve it with `git rev-parse --show-toplevel`.
- The addon uses the root-level TOC and the Lua load order declared in `RaidThreeBags.toc`.

## Working rules

- Preserve existing version history, release layout, SavedVariables contract, native WoW interactions and optional Bagnon coexistence behavior.
- Do not introduce a runtime dependency on Bagnon or other Raid Three addons.
- Keep functional Lua files ASCII-compatible and verify TOC, version identifiers and changelog together.
- Do not copy files into a live WoW client, publish to Warperia, create tags/releases or push external changes without explicit authorization.
- Distinguish static Lua validation, behavior mocks and real in-client smoke tests.
- Do not read, commit or distribute SavedVariables, credentials, tokens, webhooks or machine-local client paths.

## Verification

- Run `scripts/Validate-Release.ps1` after material release-source changes.
- Run the available Lua 5.1 syntax and behavior checks when the required runtime exists.
- Before release, verify root layout, TOC load order, version, changelog, ZIP contents and hashes.
- A release is not runtime-verified until a clean target-client load and relevant in-game smoke test have been completed.
