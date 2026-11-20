# RaidThreeBags 0.7.2

- Fixed jerky dragging/resizing and blinking Prospect/Disenchant controls.
- Profession buttons use noninteractive proxy icons while a window is being moved or resized; secure overlays return after release.
- Item selection, green-only default Disenchant, blue opt-in, epic exclusion and one hardware click per cast are unchanged.

Install: extract RaidThreeBags-0.7.2.zip into Interface/AddOns, keeping the RaidThreeBags folder.

Validation: six Lua 5.1 modules, three expanded behavior mocks, release validator and Warperia root-layout simulation passed. The user confirmed smooth dragging and resizing after a clean reload showing 0.7.2. Linked bank/settings movement and combat transitions remain mock-tested only; a full clean-install matrix remains pending. Warperia publication is a separate operation.
