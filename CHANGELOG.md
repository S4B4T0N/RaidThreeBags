# Changelog

## 0.4.3 - 2026-08-17 (GitHub alignment candidate; unreleased)

- Changed only the reported addon version from `0.4.2` to `0.4.3`.
- Aligned the local GitHub candidate branch with the exact six-file addon
  content selected for the user-reported Warperia `0.4.2` distribution.
- Kept inventory, bank, hierarchical arrangement, Sort Trace and UI behavior
  byte-identical to `0.4.2`.
- Prepared branch `codex/raid-three-bags-0.4.3` for a later explicit GitHub
  push. No push, tag or GitHub Release is part of this preparation.

## 0.4.2 - 2026-08-17

### Automatic inventory arrangement

- Added the right-edge `A-Z` inventory control and `/rtb sort` and `/rtb arrange` commands.
- Added three semantic sections in every compatible movement pool:
  - `TRASH`: poor-quality items with quality 0;
  - `CURRENT / KEEP`: after the quality-0 rule, non-poor Trade Goods regardless of age and other non-trash items first observed less than 24 hours ago;
  - `OLD / REVIEW`: other non-trash, non-Trade-Goods items first observed at least 24 hours ago and not subsequently observed absent in a complete inventory scan.
- Added one empty separator between consecutive nonempty sections and placed surplus empty slots immediately before `OLD / REVIEW`, or at the end when that section is absent.
- Replaced the earlier globally alphabetic design description with the implemented stable hierarchy: category, subtype, equipment-slot rank, character-level usability, quality descending, item level descending, lowercase name, item-ID key and original scan order.
- Kept normal bags and every exact specialty-bag family in separate movement pools.
- Added a preflight capacity check that can simulate compatible same-item partial-stack consolidation inside a pool and refuses without mutation when required separators cannot be created.
- Added one-operation-at-a-time native stack merging and item movement with confirmation after each operation and plan rebuilding after every confirmed merge.
- Added safe stops for combat, a held cursor item, locked or uncached slots, changed bag topology, unexpected inventory state and unconfirmed moves.

### Sort Trace

- Added schema-2 Sort Trace in the existing account-wide `RaidThreeBagsDB`, enabled by default and limited to the latest ten sessions.
- Added before/after snapshots, pool counts, classification and age metadata, hierarchical keys, initial and final plans, confirmed moves or merges and aggregated wait evidence.
- Added independent `PASS`, `FAIL` and `ABORTED` verification covering item-count conservation, pool isolation, exact plan agreement, hierarchy, separators, `OLD / REVIEW` placement, stable topology, readable snapshots and an empty cursor.
- Added `/rtb sortlog on|off`, `/rtb sortlog status`, `/rtb sortlog last` and `/rtb sortlog clear`.
- Documented that `sortlog off` disables both new trace retention and the independent final audit for future sessions; existing sessions remain until explicitly cleared.

### UI and validation

- Added `RaidThreeUIStyle.lua` v1.0.1 as the shared style module for inventory, bank and settings controls.
- Expanded the behavior mock to cover arrangement, partial-stack consolidation, delayed client reads, topology changes, safety refusals, Sort Trace persistence and adversarial trace verification.
- Passed source validation, official PUC Lua 5.1.5 syntax checking and the behavior mock with `SETTINGS LOGIC OK`.
- A persisted target-client schema-2 trace recorded `PASS` with 36 of 36
  arrange operations confirmed exactly. The user reports that this build was
  distributed through Warperia. Public listing visibility and Bagnon
  coexistence were not independently verified in this workspace.

## 0.4.1 - 2026-07-27

- Moved the installable `.toc`, Lua files and MIT license to repository root
  for Warperia's default-branch GitHub installer.
- Added an isolated simulation that verifies the resulting manifest path is
  `Interface/AddOns/RaidThreeBags/RaidThreeBags.toc`.
- Kept addon behavior unchanged; only repository layout and version
  identifiers changed.

## 0.4.0 - 2026-07-27

- Prepared a clean public-repository package.
- Replaced server-specific edition text with neutral WotLK 3.3.5a branding.
- Standardized maintainer metadata.
- Added `/rtb version` and English command help.
- Added release validation and an inventory/bank runtime test matrix.
- Included the MIT license in the installable addon directory, declared
  `X-License: MIT` in the manifest and validated both license copies.
- Updated the GitHub validation workflow to `actions/checkout@v7` after GitHub
  deprecated the Node.js 20 runtime used by the earlier workflow dependency.

Promoted to the stable local release source after the exact `0.4.0-dev`
candidate files matched the installed test copy by SHA-256 and the user
reported all expected in-client behavior working.
