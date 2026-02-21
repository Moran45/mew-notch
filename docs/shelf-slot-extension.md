# Shelf Slot Extension Guide

This repository keeps the `Shelf` tab as a reserved empty slot for future interactive widgets.

## Current integration points

- View entrypoint: `MewNotch/View/Notch/Expanded/ParentViews/FileShelfView.swift`
- View routing: `MewNotch/View/Notch/Expanded/ExpandedNotchView.swift`
- Tab enum: `ExpandedNotchViewModel.NotchViewType` (`Home`, `Shelf`)

`FileShelfView` is intentionally empty and only preserves layout size.

## Recommended widget contract

When adding a widget to `Shelf`, keep this contract:

1. Create a dedicated view model for widget state and actions.
2. Keep feature data/storage inside its own defaults/service layer.
3. Avoid side effects in `NotchView` and `NotchViewModel`.
4. Keep `ExpandedNotchView` as a router only.

Example shape:

```swift
struct ShelfWidgetHostView: View {
    @StateObject private var viewModel = ShelfWidgetViewModel()

    var body: some View {
        // Render widget UI
    }
}
```

## Drag and drop rules (for future work)

If reintroducing drag/drop:

1. Scope drop handling to `FileShelfView` only.
2. Do not reintroduce global drop handlers in `NotchView`.
3. Validate payload types explicitly (`URL`, `UTType`, etc.).
4. Use async processing off main thread and animate UI updates on main thread.

## State and migration guidance

- Legacy shelf storage key `Shelf_FileGroups` is now removed one-shot in `NotchDefaults`.
- If a new widget needs persistence, use a new namespace key prefix.
- Add explicit migration flags for any future schema change.
