# ClipStack

Your last 10 clippings, in the macOS menu bar. No Dock icon, no window, no
dependencies, no App Store paperwork.

Requires macOS 14+ and Swift 5.9+.

## Build & run

```bash
./build-app.sh --install     # release build, copy to /Applications, launch
./build-app.sh               # just produce ./ClipStack.app
./build-app.sh --universal   # arm64 + x86_64
```

The bundle is ad-hoc signed (`codesign --sign -`). No developer account,
provisioning profile, or notarization is involved.

## Using it

Click the menu bar icon. Your recent clippings are listed newest first — click one
to put it back on the clipboard, then paste with ⌘V as usual. Re-copying an older
clipping promotes it to the top rather than duplicating it.

**Clear** empties the history. History survives quitting and restarting.

Turn on **Launch at login** from the copy you intend to keep (`/Applications`), not
from a build directory — `SMAppService` registers whichever bundle is running.

## Passwords are skipped

Password managers tag their clippings with `org.nspasteboard.ConcealedType`, and
ClipStack ignores anything carrying that marker, along with transient and
auto-generated clippings. That check is what separates a clipboard manager from a
password logger, so leave it in place if you fork this.

It is not a guarantee: an app that copies a secret without tagging it will be
captured like any other text. History lives in plain `UserDefaults` under
`ClipStack.history` — it is not encrypted, and anything with access to your user
account can read it.

## How it works

`Sources/ClipStack/`

- **`ClipStackApp.swift`** — `@main`, `AppDelegate`, status item, popover, and the
  `SMAppService` login-item switch.
- **`ClipboardMonitor.swift`** — the pasteboard watcher and history.
- **`PopoverView.swift`** — the SwiftUI popover.

macOS posts no notification when the pasteboard changes, so the only way to observe
it is to poll `NSPasteboard.general.changeCount` — done here every 0.4s. Reading the
count is cheap and, unlike reading the contents, never trips the system's paste
privacy alert; the contents are only read once the count has actually moved.

## Known limits

- Text only. Copying an image or a file leaves the history untouched rather than
  storing a placeholder.
- Capacity is fixed at 10 (`ClipboardMonitor.capacity`).
- No global hotkey — the menu bar icon is the only way in. Adding one means an event
  tap and the Input Monitoring permission.
- Clicking a clipping puts it on the clipboard but does not paste it for you; that
  would need Accessibility access to synthesise ⌘V.
