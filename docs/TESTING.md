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
