# Warperia distribution record - RaidThreeBags 0.4.2

This page preserves the exact metadata prepared for RaidThreeBags `0.4.2`.
The user reports that its six-file package was distributed through Warperia.
Public listing visibility was not independently verified in this workspace.

## Version

`0.4.2`

## Summary

Unified inventory and personal-bank UI with safe hierarchical live-inventory arrangement for WoW 3.3.5a.

## Update description

RaidThreeBags 0.4.2 adds safe physical arrangement for the live player inventory through the `A-Z` button, `/rtb sort` or `/rtb arrange`. Items are divided into `TRASH`, `CURRENT / KEEP` and `OLD / REVIEW`, then ordered hierarchically by item category, subtype, equipment slot, level usability, quality, item level and name. Compatible bag families remain isolated, required section separators are preflighted, and compatible partial stacks may be consolidated before arrangement. A bounded local Sort Trace retains the latest ten sessions and independently verifies the result.

## Exact arrangement rules

The algorithm scans bag IDs 0, 1, 2, 3 and 4, with slots in native ascending order. Normal bags share one movement pool. Every exact nonzero specialty-bag family mask receives a separate pool and items never intentionally cross pool boundaries.

Every pool is laid out as `TRASH`, `CURRENT / KEEP`, then `OLD / REVIEW`. One empty slot separates consecutive nonempty sections. All remaining empty slots appear immediately before `OLD / REVIEW`; when no old section exists they appear at the end. Quality 0 is classified as `TRASH` first. After that rule, non-poor Trade Goods stay current regardless of age. Other eligible items become old when they were first observed at least 86,400 seconds ago and were not subsequently observed absent in a complete inventory scan.

Within a section, keys are compared in this exact order:

1. category ascending: Quest, Consumable, Weapon, Armor, Recipe, Gem, Trade Goods, Container, Projectile/Quiver, Key, Miscellaneous, then Other;
2. lowercase subtype ascending;
3. equipment slot ascending: Head, Neck, Shoulder, Back, Chest/Robe, Wrist, Hands, Waist, Legs, Feet, Finger, Trinket, Main Hand, Two-Hand, Weapon, Off Hand, Shield, Held in Off-hand, Ranged/Thrown, Relic, Tabard, Shirt/Body, Bag, Quiver, then unknown slots;
4. usable at the character's current level first;
5. quality descending;
6. item level descending;
7. lowercase name ascending;
8. item ID stored as a lexical string, then original scan order.

Preflight first simulates compatible same-item stack consolidation. If capacity is still insufficient, nothing moves. A real consolidation takes the first partial target from the front and a matching source from the back, confirms the result, then rebuilds the plan. Arrangement processes the first incorrect target from the front, searches only later slots for its desired item and performs one native operation at a time, waiting for both affected slots to become readable, unlocked and exactly confirmed.

## Changelog text

- Added the `A-Z` button and `/rtb sort` and `/rtb arrange` commands for backpack and equipped bags 0-4.
- Added `TRASH`, `CURRENT / KEEP` and `OLD / REVIEW` sections in every compatible movement pool.
- After the quality-0 `TRASH` rule, protected non-poor Trade Goods from age-based movement; other eligible items enter `OLD / REVIEW` after their retained first-observed age reaches 24 hours.
- Added one empty separator between consecutive nonempty sections and placed surplus empty slots before `OLD / REVIEW`.
- Added hierarchical order by category, subtype, equipment slot, current-level usability, quality, item level, name and deterministic tie-breakers.
- Kept normal bags and every exact specialty-bag family in separate movement pools.
- Added safe preflight and compatible partial-stack consolidation when separators require more empty slots.
- Added one-operation-at-a-time native movement with confirmation, plan rebuilding and safe stops on combat, cursor, locks, uncached data, topology changes or unexpected state.
- Added schema-2 Sort Trace with `PASS`, `FAIL` or `ABORTED` verification, retaining the latest ten sessions in `RaidThreeBagsDB`.
- Added `/rtb sortlog on|off`, `/rtb sortlog status`, `/rtb sortlog last` and `/rtb sortlog clear`.
- `sortlog off` prevents both new trace retention and the independent final audit for future sessions; retained sessions remain until `sortlog clear`.
- Added the shared `RaidThreeUIStyle.lua` module and expanded the Lua 5.1 behavior mock.

## User-visible limitations

- Arrangement covers only the live backpack and equipped bags 0-4. It does not sort the player bank, keyring, guild bank, cached characters or offline inventory.
- Item age begins when `0.4.2` first observes an item ID. Earlier ownership, removal while offline or removal/reacquisition between complete scans cannot be reconstructed.
- All copies of one item ID share an age record until a complete scan sees no remaining copy and clears it.
- Level usability checks minimum required character level only, not complete class, race, profession or skill eligibility.
- Specialty-bag families remain isolated, so several separately ordered segments may exist.
- Sort Trace remains local but contains character, realm and inventory metadata. SavedVariables must be reviewed and redacted before public sharing.
- Turning Sort Trace off does not erase retained sessions and also disables its independent final audit for future arrangements.
- Optional Bagnon coexistence requires the final in-game smoke test.

## Upload package

Use `RaidThreeBags-0.4.2.zip` only after its checksum and exact six-file manifest have been revalidated. The archive must expand to:

```text
RaidThreeBags/
  LICENSE
  RaidThreeBags.toc
  RaidThreeBags.lua
  RaidThreeUIStyle.lua
  RTB_UI.lua
  RTB_Bank.lua
```

Do not place a ZIP inside the addon folder and do not upload repository documentation, tests, scripts, SavedVariables, cache data or development governance files as addon payload.
