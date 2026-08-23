# Deprecated / unused code

Code parked here is **not compiled**. The Xcode target uses a
`PBXFileSystemSynchronizedRootGroup` on `MewNotch/`, so every file under that
folder is picked up automatically — keeping this directory at the repo root is
what makes it dead code rather than a silent build input.

## Contents

### `Shelf/FileShelfView.swift`
Former `Shelf` tab of the expanded notch: mounted-volume list (built-in +
first external disk), volume mount/unmount/rename observers, and the tap
handling that opened a disk in Finder. Also holds `RuedaColorRGBView`, the
custom HSB colour wheel, and the `Color.rgbHexString` helper.

### `Arion/`
RGB control for the ROG STRIX ARION enclosure.

- `ArionRGBController.h/.m` — Objective-C layer over IOKit/SCSI that locates the
  enclosure and writes a static colour.
- `ArionRGBService.swift` — Swift facade returning `Result`, with error codes
  mapped to readable messages.

`ArionRGBController.h` was previously exposed through
`MewNotch/Utils/Helpers/MewNotch-Bridging-Header.h`; that import has been
removed.

## Restoring

1. Move the files back under `MewNotch/` (the shelf view belongs in
   `View/Notch/Expanded/ParentViews/`, the Arion files in
   `Utils/Helpers/Arion/` and `Utils/Managers/`).
2. Re-add `#import "Arion/ArionRGBController.h"` to the bridging header.
3. Re-add a tab case in `ExpandedNotchViewModel.NotchViewType` and route it in
   `ExpandedNotchView`.

No Xcode project edits are needed — the synchronized group picks the files up
as soon as they are back inside `MewNotch/`.
