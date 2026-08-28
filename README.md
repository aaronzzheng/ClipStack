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

It captures three kinds of clipping:

| Kind | Shown as | Restored as |
|---|---|---|
| Text | The text, clamped to two lines | Plain text, plus RTF/HTML if the source had them, so formatting survives |
| Images and screenshots | A thumbnail, pixel size, file size | PNG and TIFF |
| Files copied in Finder | Finder icon, name, containing folder | The file references themselves |

Files are checked before images and images before text, because copying a file in
Finder also puts its path on as plain text and the file is the more useful thing to
hand back. A clipping is only treated as an image when there is no usable plain text
alongside it — some apps attach a decorative icon to text, and the text is what you
wanted.

**Clear** empties the history. History survives quitting and restarting.

Turn on **Launch at login** from the copy you intend to keep (`/Applications`), not
from a build directory — `SMAppService` registers whichever bundle is running.

## Passwords are skipped

Password managers tag their clippings with `org.nspasteboard.ConcealedType`, and
ClipStack ignores anything carrying that marker, along with transient and
auto-generated clippings. That check is what separates a clipboard manager from a
password logger, so leave it in place if you fork this.

It is not a guarantee: an app that copies a secret without tagging it will be
captured like any other text. History lives in
`~/Library/Application Support/ClipStack/` — `index.json` plus one PNG per image
clipping. None of it is encrypted, and anything with access to your user account can
read it. **Clear** deletes both the index and the stored images.

## How it works

`Sources/ClipStack/`

- **`ClipStackApp.swift`** — `@main`, `AppDelegate`, status item, popover, and the
  `SMAppService` login-item switch.
- **`ClipboardMonitor.swift`** — the pasteboard watcher, the history, and its
  on-disk store.
- **`PopoverView.swift`** — the SwiftUI popover.

macOS posts no notification when the pasteboard changes, so the only way to observe
it is to poll `NSPasteboard.general.changeCount` — done here every 0.4s. Reading the
count is cheap and, unlike reading the contents, never trips the system's paste
privacy alert; the contents are only read once the count has actually moved.

## Known limits

- Capacity is fixed at 10 (`ClipboardMonitor.capacity`). Images above 25 MB are
  skipped rather than stored, and RTF/HTML variants above 512 KB are dropped while
  the plain text is kept.
- Image clippings are re-encoded to PNG. A copied image that was originally
  something else comes back as a PNG.
- No global hotkey — the menu bar icon is the only way in. Adding one means an event
  tap and the Input Monitoring permission.
- Clicking a clipping puts it on the clipboard but does not paste it for you; that
  would need Accessibility access to synthesise ⌘V.
