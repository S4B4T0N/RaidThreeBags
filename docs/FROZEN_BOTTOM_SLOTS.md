# Frozen bottom slots

## Behavior

When the inventory or live personal-bank `A-Z` arrangement starts, each compatible bag pool identifies its occupied bottom tail. Starting at the last displayed slot of that pool, every consecutive occupied slot is frozen until the first empty slot is reached.

Frozen slots:

- stay at their original bag and slot coordinates;
- are excluded from normal sorting swaps and move sources;
- remain represented at the same positions in the desired plan;
- may receive a compatible partial-stack merge from an unfrozen source;
- are not treated as available separator or destination slots for normal rearrangement.

The rule is applied independently to the character inventory and the live personal bank. Specialty-bag families remain separate compatible pools, as before.

## Example

If the bottom slot contains `Potion of Speed x10` and another slot contains `Potion of Speed x1`, the bottom slot remains fixed and may receive the merge, producing `Potion of Speed x11` in the original bottom slot.

## Safety

The sorter does not silently re-freeze or overwrite an unexpected external change. If a frozen slot no longer contains the planned item while sorting is in progress, the session stops and records the failure in Sort Trace.

## Scope

This behavior applies to `A-Z` inventory and bank arrangement. It does not change the separate recent-item transfer commands. No user setting is required; the behavior is automatic for every arrangement session.
