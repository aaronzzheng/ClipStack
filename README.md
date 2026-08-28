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

**Clear** empties the history. History survives quitting, restarting, and shutdown —
it is on disk, not in memory.

## Shortcuts

| Shortcut | Does |
|---|---|
| `⌘⇧V` | Strip the clipboard to plain text and paste it |
| `⌥⌘V` | Open the ClipStack popover |

Once it is open, it is entirely keyboard-driven:

| Key | Does |
|---|---|
| `1`–`9`, `0` | Copy that numbered clipping and close — the numbers down the left of each row are the keys |
| `↑` `↓` | Move the highlight |
| `return` | Copy the highlighted clipping |
| `esc` | Close |

Keys are only intercepted while the popover is open, and only when nothing is held —
`⌘Q` still quits.

So `⌥⌘V` then `2` is the whole interaction, without your hands leaving the keyboard.

Both are registered with `RegisterEventHotKey`, which needs **no** privacy
permission — unlike a `CGEventTap`, which would require Input Monitoring. If another
app already owns a combination, registration fails quietly and everything else keeps
working.

`⌘⇧V` is the one worth building a habit around: pasting into Word, Outlook, or
PowerPoint stops dragging the source's fonts and colours along with it.

Pressing ⌘V *for* you does need Accessibility, and it is requested the first time you
use `⌘⇧V`. Decline it and the shortcut still strips the clipboard — you just press ⌘V
yourself. The feature degrades instead of dying.

## Transforming the clipboard

The wand menu in the popover header acts on whatever is on the clipboard now:

- **Strip Formatting** — drop the RTF/HTML variants, keep the text
- **Strip Tracking Parameters** — remove `utm_*`, `fbclid`, `gclid`, `si` and friends
  from a copied URL
- **Pretty-Print JSON**
- **URL-Decode**

A transform that does not apply — no JSON, no tracking parameters — leaves the
clipboard untouched rather than mangling it. The same menu lists the shortcuts above,
since a global hotkey is otherwise undiscoverable.

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
- **`ClipboardMonitor.swift`** — the pasteboard watcher, the history, its on-disk
  store, and the clipboard transforms.
- **`HotKeyManager.swift`** — Carbon global hotkeys.
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
- Shortcuts are hardcoded in `HotKeyManager.Shortcut`. There is no UI to rebind them.
- Clicking or picking a clipping puts it on the clipboard but does not paste it; only
  `⌘⇧V` pastes for you.
