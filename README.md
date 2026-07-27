# RaidThreeBags

RaidThreeBags is a unified, resizable inventory and player-bank addon for World of Warcraft: Wrath of the Lich King 3.3.5a.

## Project status

`0.4.0` is the stable local release source. It passes static validation and
the retained behavior mock. On 2026-07-27 the exact development candidate was
copied into a WotLK 3.3.5a client, matched the candidate files by SHA-256 and
passed user-operated in-client verification. The source repository is public
at [github.com/S4B4T0N/RaidThreeBags](https://github.com/S4B4T0N/RaidThreeBags),
and its GitHub Actions release validation passes on `main`. Release archives
are published on the [GitHub Releases page](https://github.com/S4B4T0N/RaidThreeBags/releases).
The project has not yet been submitted to Warperia.

## Features

- unified inventory grid;
- player-bank window shown while interacting with a banker;
- live bag-slot and item updates;
- item cooldowns and lock state;
- configurable visibility of profession and class bag families;
- resizable, movable or locked windows;
- optional coexistence handling for Bagnon.

Settings and window positions are account-wide by design. The addon does not use guild identity, remote services or credentials.

## Install

Copy the inner `RaidThreeBags` directory into `World of Warcraft/Interface/AddOns/`. The final manifest path must be:

```text
Interface/AddOns/RaidThreeBags/RaidThreeBags.toc
```

## Commands

```text
/rtb
/rtb bank
/rtb settings
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

See [TESTING.md](docs/TESTING.md) for the required in-client checks.

When a PUC Lua 5.1 runtime is available, the retained behavior mock can be run with:

```text
lua tests/SettingsLogicMock.lua RaidThreeBags
```

## Compatibility

- WoW client: 3.3.5a (`Interface: 30300`)
- Lua: 5.1-era WoW API
- Bagnon: optional dependency/coexistence path

## License

MIT. See the repository [LICENSE](LICENSE). An identical copy is included as
[`RaidThreeBags/LICENSE`](RaidThreeBags/LICENSE), so the copyright and
permission notice remain present when only the installable addon directory is
packaged.
