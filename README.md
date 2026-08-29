# RaidThreeBags

RaidThreeBags is a unified, resizable inventory and player-bank addon for World of Warcraft: Wrath of the Lich King 3.3.5a.

## Project status

`0.4.3` is the current release candidate. It adds live player-bank sorting, bank transfer controls and the matching schema-2 Sort Trace coverage described below. Static validation, official PUC Lua 5.1.5 parsing, the retained behavior mock and Warperia GitHub-layout simulation pass. A fresh direct client smoke test remains the final release gate.

`0.4.2` is the previous stable source line. The public repository is being updated from the prepared `release` branch so Warperia can consume the new default-branch content.

The public repository is [github.com/S4B4T0N/RaidThreeBags](https://github.com/S4B4T0N/RaidThreeBags).

## Features

- unified inventory grid;
- player-bank window shown while interacting with a banker;
- live bag-slot, item, cooldown, lock and money updates;
- configurable visibility of profession and class bag families;
- movable, resizable and lockable windows;
- optional coexistence handling for Bagnon;
- safe physical arrangement of the live inventory through the `A-Z` button, `/rtb sort` or `/rtb arrange`;
- retained Sort Trace for the latest ten arrangement sessions.

Settings, window positions, item-age records and Sort Trace are account-wide in `RaidThreeBagsDB`. The addon does not use network services or credentials.

## Inventory arrangement

Arrangement covers only the backpack and equipped bags 0-4. It does not sort the player bank, keyring, guild bank, cached characters or offline inventory.

Normal bags form one movement pool. Every exact nonzero specialty-bag family forms its own pool, so an item is never intentionally moved across incompatible bag families. Within each pool, items are divided into:

1. `TRASH`: poor-quality items with quality 0.
2. `CURRENT / KEEP`: after the quality-0 rule, non-poor Trade Goods regardless of age, plus other non-trash items first observed less than 24 hours ago.
3. `OLD / REVIEW`: other non-trash, non-Trade-Goods items first observed at least 24 hours ago and not subsequently observed absent in a complete inventory scan.

One empty slot separates consecutive nonempty sections. Any remaining empty slots are placed immediately before `OLD / REVIEW`, or at the end of the pool when that section is absent.

Items inside each section are ordered hierarchically by:

1. category: Quest, Consumable, Weapon, Armor, Recipe, Gem, Trade Goods, Container, Projectile/Quiver, Key, Miscellaneous, then Other;
2. lowercase subtype;
3. physical equipment-slot rank: Head, Neck, Shoulder, Back, Chest/Robe, Wrist, Hands, Waist, Legs, Feet, Finger, Trinket, Main Hand, Two-Hand, Weapon, Off Hand, Shield, Held in Off-hand, Ranged/Thrown, Relic, Tabard, Shirt/Body, Bag, Quiver, then unknown slots;
4. items usable at the character's current level first;
5. quality, highest first;
6. item level, highest first;
7. lowercase name;
8. item-ID key as a lexical string, then original inventory scan order, as deterministic tie-breakers.

This is hierarchical ordering, not global alphabetical ordering. Item age is keyed by realm, character and item ID. All copies of the same item ID share one first-observed time until a later complete inventory scan sees no remaining copy and clears the record. The addon cannot prove uninterrupted possession between scans or while offline, and ownership before its first observation cannot be reconstructed.

Before moving anything, the addon checks cursor, combat, item locks, item-cache completeness, bag topology and separator capacity. It simulates compatible same-item partial-stack consolidation only inside the same movement pool and refuses before mutation if separators still cannot be created. During consolidation, it selects the first partial target from the front and a matching source from the back, confirms one native merge, then rebuilds the complete plan.

For arrangement, the addon takes the first incorrect target slot from the front, searches only later slots for the required item and either swaps it into the target or moves it through a later empty slot. Only one logical merge or swap is outstanding at a time; it uses the native `PickupContainerItem` pickup sequence and must leave both affected slots readable, unlocked and exactly confirmed before the next logical operation. The session stops on changed topology, unexpected inventory state or an unconfirmed result.

## Sort Trace and privacy

Sort Trace is enabled by default and retains the latest ten sessions locally in `RaidThreeBagsDB`. It records character and realm names, timestamps, bag topology, item IDs and names, counts, bag/slot coordinates, classification and age metadata, plans, confirmed moves or merges, wait evidence and a `PASS`, `FAIL` or `ABORTED` result. Turning logging off prevents both new trace retention and the independent final audit for future sessions; retained sessions remain until `/rtb sortlog clear`. The addon does not transmit data and does not record chat, character location or credentials. Review and redact SavedVariables before sharing them publicly.

## Install

Extract the release ZIP into `World of Warcraft/Interface/AddOns/`. The repository root represents the contents of the `RaidThreeBags` addon folder for GitHub-backed installers. The final manifest path must be:

```text
Interface/AddOns/RaidThreeBags/RaidThreeBags.toc
```

## Commands

```text
/rtb
/rtb bank
/rtb settings
/rtb sort
/rtb arrange
/rtb sortlog on|off
/rtb sortlog status
/rtb sortlog last
/rtb sortlog clear
/rtb reset
/rtb reset inventory
/rtb reset bank
/rtb version
/rtb help
```

The bank command only displays usable bank content while the normal banker interaction is open. Bag-equipment controls invoke the standard client bag-slot functions from explicit user clicks.

## Validation

Run:

```powershell
./scripts/Validate-Release.ps1
```

With PUC Lua 5.1 available, run:

```text
lua tests/SettingsLogicMock.lua .
```

See [TESTING.md](docs/TESTING.md) for in-client evidence and [WARPERIA_UPDATE_0.4.2.md](docs/WARPERIA_UPDATE_0.4.2.md) for the preserved `0.4.2` Warperia metadata.

## Compatibility

- WoW client: 3.3.5a (`Interface: 30300`)
- Lua: 5.1-era WoW API
- Bagnon: optional dependency/coexistence path; combined runtime verification remains pending

## License

MIT. See [LICENSE](LICENSE). The root-level license is included inside the installable `RaidThreeBags` directory in every release ZIP.
