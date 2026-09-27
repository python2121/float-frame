# Float Frame — plan

Float Frame is a fork of [Haruna](https://invent.kde.org/multimedia/haruna) with
two additions:

1. **Chromeless mode** — no title bar, no header, no menu bar, no docked footer.
   Only the video, plus Haruna's existing floating controls on mouse movement.
   The window is still a normal KDE window: click-drag anywhere to move it,
   drag the edges to resize it.
2. **Crop to content** — pause, drag a rectangle over the part of the frame that
   is the real picture, and the player crops the video to it and resizes the
   window so the floating window *is* the content (no letterbox, no pillarbox,
   no burned-in UI from screen recordings).

Everything else stays Haruna. The fork tracks upstream `master` and rebases,
so changes are kept small and confined to a few files.

## Repo layout

| Path | What |
|---|---|
| `main` branch | Float Frame. Upstream remote is `upstream`, tracked by the local `master` branch. |
| `flatpak/` | Manifest (`io.github.python2121.FloatFrame.yml`), `build.sh`, two patches copied from Flathub. Build outputs are gitignored. |
| `docs/PLAN.md` | This file. |
| `src/qml/Main.qml` | Window; where chromeless mode and crop hook in. |
| `src/qml/MpvVideo.qml` | Video item + mouse handling; crop selection overlay goes here. |
| `src/qml/Footer.qml` | Floating controls (already exist upstream as `footerStyle == "floating"`). |
| `src/models/actionsmodel.cpp` / `.h` | Action registry (name, text, icon, default shortcut) + signals. |
| `src/qml/Actions.qml` | Maps action signals to behaviour. |
| `src/settings/generalsettings.kcfg` | Persisted settings (KConfigXT). |
| `src/mpv/mpvitem.{h,cpp}`, `src/mpv/mpvproperties.h` | mpv property names and observers. |

## Build

SteamOS has a read-only root and no compiler, so the app is built and run as a
**Flatpak**. The manifest is Flathub's `org.kde.haruna` manifest with three
changes: a new app-id, `rename-*` entries for the desktop/appdata/icon files,
and the `haruna` module built from the checkout (`type: dir`) instead of the
release tarball.

- Runtime/SDK: `org.kde.Platform` / `org.kde.Sdk` **6.11** (already installed).
  It ships Qt 6.11 and KDE Frameworks 6.30; upstream master needs Qt ≥ 6.8 and
  KF ≥ 6.21, so master builds against it without extra KF modules.
- Built from source inside the flatpak: libmpv 0.41 (+ luajit, libplacebo,
  libass, uchardet, libXpresent), mpvqt 1.2, KDSingleApplication, kfilemetadata
  6.28, yt-dlp. The first build is slow (mpv + libplacebo); later builds hit
  the `.flatpak-builder` cache and ccache.
- `flatpak/build.sh` runs `org.flatpak.Builder` (installed as a Flatpak), so
  nothing is needed on the host. `flatpak run io.github.python2121.FloatFrame`.

## Phase 0 — baseline (done 2026-09-26)

- [x] Clone upstream, `main` branch, `upstream` remote.
- [x] Flatpak manifest + build script.
- [x] Unmodified master (v1.8.1-312-gf727be24) builds and runs as
  `io.github.python2121.FloatFrame` next to Flathub Haruna. First build ≈ 25 min
  on the Deck; the haruna module alone rebuilds in a few minutes.

Known wrinkle: the binary still calls itself `org.kde.haruna` (KAboutData
`setDesktopFileName`, MPRIS name, config dir `~/.config/haruna`), so the Wayland
`app_id` is `org.kde.haruna` while the exported desktop file is the fork id.
KWin falls back to the Flatpak id from `/.flatpak-info` for icon/task-manager
matching, so this works but is not clean — fixed in Phase 2.

## Phase 1 — chromeless mode (done 2026-09-26; manual drag/resize check pending)

**What exists already.** Haruna can hide the header (`GeneralSettings.showHeader`)
and menu bar (`showMenuBar`) and has a floating footer (`footerStyle = "floating"`,
shown on mouse movement, auto-hides after 1 s). So "no chrome inside the window"
is a matter of setting three existing settings. What is missing is removing
the **window frame** and still being able to move/resize.

**Design.**

- New setting `GeneralSettings.chromeless` (bool) and a new action
  `toggleChromelessAction` (default shortcut `Ctrl+Shift+F`, free upstream). Registered in `actionsmodel.cpp/.h`, handled in
  `Actions.qml`, added to the View menu and the hamburger menu.
- In `Main.qml`, when chromeless:
  - `flags: Qt.Window | Qt.FramelessWindowHint`. On Wayland this tells KWin via
    `xdg-decoration` not to draw server-side decorations; Qt draws no
    client-side ones either. The window stays a regular toplevel: KWin's
    Meta+drag, Alt+F3 menu, window rules, tiling and virtual desktops all
    keep working — that is what "first-class citizen" buys us over an
    override-redirect/OSD-style surface.
  - Force header/menubar hidden and footer floating (read the three settings
    through a "chromeless overrides" layer rather than clobbering the user's
    saved values, so toggling back restores their layout).
  - Background colour → black (no themed background bleeding around the video).
- **Move:** in `MpvVideo.qml` add a `DragHandler` (or extend the existing
  `MouseArea`) that calls `window.startSystemMove()` once a left-button drag
  exceeds the drag threshold. This is the Qt 5.15+/Qt 6 API that maps to
  `xdg_toplevel.move` on Wayland; the compositor does the move, so it feels
  identical to dragging a title bar. Plain clicks (no drag) keep firing the
  configured mouse action (play/pause), double-click keeps toggling fullscreen.
- **Resize:** an 8 px invisible border of hover areas along the four edges and
  corners, each setting `cursorShape` and calling
  `window.startSystemResize(Qt.LeftEdge | Qt.TopEdge …)` on press. Again the
  compositor does the work.
- Chromeless is orthogonal to fullscreen; fullscreen already hides everything.
- Toggling `flags` at runtime on Wayland: **tested** with
  `docs/spikes/frameless.qml` (run with
  `flatpak run --socket=wayland --filesystem=home --command=qml org.kde.Sdk//6.11 -platform wayland <abs path> -- --auto`).
  Flipping `Qt.FramelessWindowHint` four times kept the window visible,
  Windowed, and at the same geometry — no surface recreation visible from the
  client side. So a live toggle is fine. Still to eyeball: KWin actually drops
  the title bar each time, and `startSystemMove`/`startSystemResize` feel
  (needs a human with a mouse; the spike has both wired up).
- Startup: `--chromeless` command line flag in `commandlineoptions.cpp` so a
  desktop-file action ("Open chromeless") and KWin rules can target it.

**Status.** Implemented as designed. Automated check: `scripts/test-chromeless.sh`
launches the flatpak and asks KWin for frame vs client geometry (equal ⇒ no
decoration); passes for `--chromeless`, for the saved setting, and shows the
29 px title bar for a plain launch. `--chromeless` is a session-only override
(`HarunaApp.chromelessOverride`) and does not leak into the config. Still needs
a human: drag-to-move feel, edge/corner resize, live toggle with Ctrl+Shift+F.

Extra: right-click while the context menu is showing now closes it instead of
reopening it at the pointer (`MpvContextMenu.toggle()`).

## Phase 2 — make it its own app

Rename so it coexists with Flathub Haruna and is a proper KDE citizen:

- App id `io.github.python2121.FloatFrame`: `KAboutData::setDesktopFileName`,
  `QApplication::setApplicationName("floatframe")`, MPRIS service name,
  KDSingleApplication key. (Config/DB already live in the sandboxed
  `~/.var/app/io.github.python2121.FloatFrame/`, so no clash with Haruna's
  files even before the rename; the clash is only D-Bus names and the
  Wayland `app_id`.)
- `data/`: rename desktop file, metainfo, icon (new icon later; reuse
  Haruna's for now — GPL-3.0-or-later, keep the copyright notices).
- Drop the `rename-*` lines from the manifest once the sources use the new id.
- Desktop file: add an `Actions=` entry for chromeless launch; keep
  `MimeType=` so it shows in "Open with" for video files.
- Optional: "Keep above" toggle. KWin on Wayland has no client API for
  keep-above (KWindowSystem's `setState` is X11-only), so document a KWin
  window rule for the app id instead, or ship one via `kwinrulesrc` example.

**Estimate:** small, mostly mechanical. Do it before Phase 3 so testing does
not disturb the installed Haruna.

## Phase 3 — crop to content

**mpv side.** libmpv 0.41 has the `video-crop` property (`WxH+X+Y`, source
pixels, applies live without reloading the file). Reset with `video-crop=""`.
It changes `video-out-params/{dw,dh}` and the render size, so Haruna's
"resize window to video" logic can key off it.

**Coordinate mapping.** The video is letterboxed inside the `MpvItem`. mpv
exposes `osd-dimensions` (`w`, `h`, `ml`, `mr`, `mt`, `mb`): the render target
size and the margins around the picture, in render pixels. Multiply item
coordinates by `Screen.devicePixelRatio` (mpvqt renders at item size × DPR),
subtract the margins, scale by `video-params/w / (w − ml − mr)` (and `h`
likewise) to get source pixels. Anamorphic content is covered because we
scale from displayed size to `video-params/w,h` (storage size), which is what
`video-crop` expects. Apply an existing crop offset if one is already set.

**UI.**

- Action `cropToContentAction`, default shortcut **`C`** (user’s choice; unused upstream) → pauses, enters *crop mode*: a
  dimmed overlay over `MpvVideo` with a `DragHandler`; drag draws a rectangle,
  handles on the corners/edges to adjust, Enter/double-click applies, Esc
  cancels. Action `resetCropAction` clears it. Both in the Video menu, the
  hamburger menu and the mpv context menu.
- Snap the rectangle to even source coordinates (chroma subsampling; mpv
  rounds anyway but even numbers avoid a one-pixel shift).
- After applying: set `video-crop`, then resize the window so its content
  area matches the crop aspect. In chromeless mode the window *is* the
  content, so `window.width = cropW * scale`, `window.height = cropH * scale`
  where `scale` keeps the current window width (or fits the screen).
  Upstream disables `resizeWindow()` on Wayland; a client *can* set its own
  size on Wayland (KWin honours it unless the window is maximized/tiled), so
  the guard becomes "not fullscreen, not maximized". Test.
- Optional **auto-detect** button in crop mode: add
  `vf add @cd:lavfi=[cropdetect=limit=24:round=2:reset=0]`, step a few frames
  (`frame-step`), read `vf-metadata/cd/lavfi.cropdetect.{w,h,x,y}`, remove the
  filter, and pre-fill the rectangle. Handles the common black-bars case with
  one click; the manual rectangle stays for burned-in UI.
- Remember crop per file: store in the existing SQLite `playback_position`
  table (or a new `crop` table via `migrationmanager.cpp`) and reapply on load.

**Aspect lock while resizing.** xdg-shell has no aspect-ratio hint, so KWin
cannot constrain an interactive resize. Options:
  1. After the user finishes resizing (debounce ~150 ms on width/height
     change), snap the smaller-changed dimension to the crop aspect. Simple,
     one visible "settle". **Recommended first cut.**
  2. Do resizing client-side for the right/bottom edges (set `window.width`
     and `window.height` together during the drag → live aspect lock) and
     use `startSystemResize` + snap for left/top (a client cannot set its own
     position on Wayland, so growing "leftwards" needs the compositor).
  Either way the black bars only appear during the drag.

**Estimate:** medium. Crop mode overlay ~250 lines QML; mapping + a few
observed properties ~80 lines C++ in `mpvitem.cpp`; persistence ~60 lines.

## Phase 4 — polish

- Remember chromeless + window geometry (`KConfig.WindowStateSaver` already
  exists behind `rememberWindowGeometry`).
- OSD hints the first time chromeless is entered ("drag to move, edges to
  resize, `Ctrl+Shift+F` to restore").
- Cursor auto-hide in chromeless (upstream only hides in fullscreen).
- Touch (Deck screen): 8 px resize edges are ~1 mm and a 10 px drag threshold
  turns wobbly taps into moves. Enlarge handles / threshold for touch devices
  (`PointerDevice.TouchScreen`), or add a `DragHandler` with a bigger threshold.
- The compositor's pointer grab during a move also fires Haruna's
  `applicationMouseLeave`, which starts the floating footer's hide timer
  (cosmetic).
- Keyboard-only crop nudging (arrow keys move/resize the rectangle by 2 px).
- Upstream rebase routine: `git fetch upstream && git rebase upstream/master`
  on `main`; conflicts should be limited to `Main.qml`, `MpvVideo.qml`,
  `actionsmodel.cpp`, `generalsettings.kcfg`.

## Open questions

- Default shortcut for chromeless: `Ctrl+Shift+F` (free upstream). Crop: `C`, decided. Remaining new actions (must not collide with
  `actionsmodel.cpp` defaults; upstream uses most single letters).
- Should the crop also drive `--video-zoom`/`--video-pan` instead of
  `video-crop`? `video-crop` is cleaner (subtitles reposition, screenshots
  respect it); zoom/pan is a fallback if `video-crop` misbehaves with
  hardware decoding on the Deck (AMD VAAPI) — verify on real files.
- New icon and name in the app (window title says "Haruna" today).
