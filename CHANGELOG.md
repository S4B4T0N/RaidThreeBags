# Changelog

## 0.7.2 - 2026-11-20

- Fix jerky window dragging/resizing and blinking profession controls by suspending their secure-overlay refresh during manipulation.
- Display noninteractive proxy icons while moving/resizing; restore secure overlays after release or hide. Block profession clicks during the interaction and preserve combat restrictions.
- Keep item selection, green/blue/epic policies and one-click-per-cast behavior unchanged.
- User confirmed smooth dragging and resizing after a clean reload of 0.7.2. Six-module Lua 5.1 syntax, three expanded mocks and release/layout validation pass; linked-window/combat paths remain mock-tested only.

## 0.7.1 - 2026-11-20

- Remove the extra central Quickslot square from inventory/bank transfer buttons; keep the two arrows and outer frame.
- Add Jewelcrafting Prospect button with full inventory scanning and optional small-stack ore merging.
- Add Enchanting Disenchant button: green gear by default, blue opt-in, epics always excluded. Revalidate item identity/quality and clear residual spell targeting.
- One hardware click per cast; profession settings persist account-wide. Preserve frozen-bottom sorting and existing bank behavior.
- Static validation and three Lua 5.1 mocks cover selection, settings and action coordination. User confirmed Disenchant in 0.7.0; earlier single-dose Prospect test passed. New icon and full clean-client/combat matrix remain unverified.


## 0.4.4 - 2026-08-29 (development)

- Added frozen occupied bottom-tail slots to inventory and live personal-bank arrangement.
- Frozen slots remain at their original positions and cannot be normal swap targets or sources.
- Compatible partial stacks may still merge into a frozen bottom stack.
- Added Sort Trace coverage for frozen-slot preservation, merge-target behavior and unexpected frozen-slot changes.

## 0.4.3 - 2026-08-29

- Added frozen occupied bottom-tail slots for inventory and live bank arrangement. These slots remain fixed during swaps, while compatible partial stacks may still merge into them.

- Added live personal-bank arrangement with the same safe three-section hierarchy as inventory sorting.
- Added matching bank-side `A-Z` sorting control.
- Added `/rtb sort bank` and `/rtb arrange bank` commands.
- Added bidirectional recent-item transfer controls between character bags and the live personal bank.
- Added `/rtb transfer bank` and `/rtb transfer bags` commands.
- Extended schema-2 Sort Trace snapshots, confirmed operations and final invariant auditing to bank sorting and transfer sessions.
- Preserved compatible bag-pool isolation, one-operation-at-a-time native pickup handling, stack consolidation, topology guards and safe stops for combat, cursor, lock, cache and confirmation failures.
- Updated the addon version and release documentation to `0.4.3`.

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

### UI and validation

- Added `RaidThreeUIStyle.lua` v1.0.1 as the shared style module for inventory, bank and settings controls.
- Expanded the behavior mock to cover arrangement, partial-stack consolidation, delayed client reads, topology changes, safety refusals, Sort Trace persistence and adversarial trace verification.

## 0.4.1 - 2026-07-27

- Moved the installable `.toc`, Lua files and MIT license to repository root for Warperia's default-branch GitHub installer.
- Added an isolated simulation that verifies the resulting manifest path is `Interface/AddOns/RaidThreeBags/RaidThreeBags.toc`.
- Kept addon behavior unchanged; only repository layout and version identifiers changed.

## 0.4.0 - 2026-07-27

- Prepared a clean public-repository package.
- Replaced server-specific edition text with neutral WotLK 3.3.5a branding.
- Standardized maintainer metadata.
- Added `/rtb version` and English command help.
- Added release validation and an inventory/bank runtime test matrix.
- Included the MIT license in the installable addon directory, declared `X-License: MIT` in the manifest and validated both license copies.
