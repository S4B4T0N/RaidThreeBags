# In-client test plan

Static validation cannot verify protected-action behavior or item safety. Use a test character and back up the account’s `WTF` directory.

## Inventory checks

1. Open, close and toggle with key bindings and `/rtb`.
2. Move, resize, lock and reset the inventory window.
3. Verify empty, full and partially filled bags.
4. Move, split, use and link items through normal client interactions.
5. Equip and remove ordinary, profession, quiver, ammo and soul bags only through explicit clicks.
6. Verify hidden special-bag settings and free-slot counts.
7. Verify item cooldown, lock and money updates.

## Bank checks

1. Confirm the custom bank remains unavailable away from a banker.
2. Open and close the normal banker interaction repeatedly.
3. Deposit, withdraw, split and move items between inventory and purchased bank bags.
4. Verify bank bag replacement and purchase states.
5. Verify the window closes when the banker interaction ends.

## Compatibility checks

1. Test with Bagnon absent.
2. Test with the supported Bagnon version enabled.
3. Test at common UI scales and resolutions.
4. Reload and relog to verify account-wide settings.
5. Confirm no Lua errors, blocked protected actions, item loss, duplicated display slots or stale bank data.

Record client/server build, addon set, result and stack traces. Promote the version only after all applicable checks pass.

## Frozen bottom-slot checks - 0.4.4

1. Fill the last displayed slot of an inventory or bank compatible pool with an item and place a sortable item above it.
2. Press `A-Z` and confirm the occupied bottom item stays in the same slot.
3. Place another stack of the same item above it and confirm the stack may merge into the frozen bottom stack without moving the bottom slot.
4. Change the frozen slot externally during a long sort and confirm sorting stops with a verification message rather than moving the frozen item.
5. Repeat the checks for the live personal bank while interacting with a banker.
## Automatic-arrangement checks - 0.4.3

Use expendable test items and preserve a backup of `WTF/Account/<account>/SavedVariables/RaidThreeBags.lua` before the first test.

1. Run `/reload`, confirm `RaidThreeBags 0.4.3` loads without Lua errors and verify the 30 px `A-Z` control is at the right edge of the upper bag-control row.
2. Run the same arrangement once through `A-Z`, once through `/rtb sort` and once through `/rtb arrange`.
3. Build an inventory containing poor-quality items, Trade Goods, new non-trade items and non-trade items whose retained first-observed timestamp is at least 24 hours old.
4. Confirm each compatible movement pool uses `TRASH`, `CURRENT / KEEP`, `OLD / REVIEW`, one empty separator between consecutive nonempty sections and all surplus empty slots immediately before `OLD / REVIEW`.
5. When `OLD / REVIEW` is absent, confirm surplus empty slots are at the end of that pool.
6. Confirm internal order is hierarchical rather than globally alphabetic: category, subtype, equipment-slot rank, current-level usability, quality descending, item level descending, lowercase name and deterministic tie-breakers.
7. Test normal bags and at least one specialty-bag family. Confirm no item crosses between incompatible movement pools.
8. Create compatible same-item partial stacks whose consolidation is required to create separators. Confirm the entire consolidation and arrangement complete in one user-triggered session without item-count change.
9. Remove separator capacity that consolidation cannot recover. Confirm the preflight refuses before moving any item.
10. Confirm arrangement refuses during combat, with an item held on the cursor, with a locked item and while required item information is not cached.
11. During a controlled test, change an equipped bag after planning but before the next move. Confirm the topology check stops the session before another physical move.
12. Confirm short stale reads or temporary post-move locks are waited through, while unexpected or unconfirmed state stops safely.
13. After success, run `/rtb sortlog last` and inspect `RaidThreeBagsDB.sortTrace` after logout or `/reload`. Confirm schema 2, `PASS`, complete before/after data, item totals, pool assignments, plans and confirmed operations.
14. Trigger a capacity refusal and confirm an `ABORTED` trace. Test `/rtb sortlog off`, `status`, `on` and `clear`.
15. Repeat the complete smoke test with Bagnon absent and with the supported Bagnon installation enabled.

The final promotion gate is a target WoW 3.3.5a run of steps 1-15. PUC Lua syntax and mock results do not replace this runtime evidence.

## GitHub alignment verification - 0.4.3

- The exact source baseline passed `scripts/Validate-Project.ps1` on 2026-08-17.
- All four deployable Lua modules and `tests/SettingsLogicMock.lua` passed official PUC Lua 5.1.5 syntax checking.
- The expanded behavior mock passed under official PUC Lua 5.1.5 with `SETTINGS LOGIC OK`.
- After normalizing only TOC/Lua version identifiers, all six deployable
  `0.4.3` files match the distribution-selected `0.4.2` content exactly.
- A persisted target-client `0.4.2` schema-2 trace recorded `PASS`: 36 of 36
  arrange operations matched expected source/target IDs and counts, with
  conserved totals, pool isolation, plan/hierarchy agreement, valid
  separators, stable topology, complete snapshots and an empty cursor.
- That live run covered general, herb and mining pools. It did not exercise
  real OLD-content placement, stack consolidation or Bagnon coexistence.
- `0.4.3` makes no behavior change, but a direct `0.4.3` client load remains
  the strict version-specific runtime check before a tag or GitHub Release.

## Runtime verification - 2026-07-27

- The user copied the complete `0.4.0-dev` installable directory into a WotLK
  3.3.5a client.
- Before promotion, SHA-256 comparison confirmed that all five installed files
  matched the distribution candidate: `LICENSE`, `RaidThreeBags.lua`,
  `RaidThreeBags.toc`, `RTB_Bank.lua` and `RTB_UI.lua`.
- User-provided screenshots confirm that the client loaded
  `RaidThreeBags 0.4.0-dev` and displayed both the inventory and player-bank
  windows at a banker with the neutral WotLK branding.
- The user reported that all expected behavior worked and reported no errors.
- Screenshots were not copied into the repository because they contain
  unrelated player and chat data.
- Promotion to `0.4.0` changed only source-controlled version identifiers and
  documentation after this runtime verification; addon behavior was not
  changed.

## Packaging verification - 0.4.1

- `0.4.1` changes only the repository layout and reported version.
- `RTB_Bank.lua` and `RTB_UI.lua` remain byte-identical to `v0.4.0`.
- `RaidThreeBags.lua` differs only in `RTB.VERSION`.
- `RaidThreeBags.toc` differs only in the title and version values.
- The isolated Warperia GitHub-layout simulation verifies the final path
  `Interface/AddOns/RaidThreeBags/RaidThreeBags.toc` and all files referenced
  by the manifest.
- The existing in-client behavior evidence therefore applies to the unchanged
  Lua behavior. No fresh live-client runtime claim is made for the packaging
  operation itself.
