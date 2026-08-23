# Notch Tab Slot Guide

The expanded notch has a tab switcher (`NotchTabSwitcherView`) with two tabs:
`Home` and `Claude`. The `Claude` tab is a reserved empty slot for the feature
being built next.

## Current integration points

- View entrypoint: `MewNotch/View/Notch/Expanded/ParentViews/ClaudeView.swift`
- View routing: `MewNotch/View/Notch/Expanded/ExpandedNotchView.swift`
- Tab switcher: `MewNotch/View/Notch/Expanded/Controls/NotchTabSwitcherView.swift`
- Tab enum: `ExpandedNotchViewModel.NotchViewType` (`Home`, `Claude`)

`ClaudeView` is intentionally empty and only preserves layout size.

## Recommended widget contract

When filling the slot, keep this contract:

1. Create a dedicated view model for widget state and actions.
2. Keep feature data/storage inside its own defaults/service layer.
3. Avoid side effects in `NotchView` and `NotchViewModel`.
4. Keep `ExpandedNotchView` as a router only.

## Tab icons

`NotchViewType.imageSystemName` returns an SF Symbol name. The `Claude` tab
currently uses `asterisk` as a stand-in; swap it for a bundled image asset when
the real artwork is available.

## Previous occupant

The storage shelf that used to own the second tab — disk list plus ROG STRIX
ARION RGB control — is parked, uncompiled, in `Deprecated/`. See
`Deprecated/README.md` for what it contains and how to restore it.
