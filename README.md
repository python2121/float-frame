# Float Frame

A fork of [Haruna](https://invent.kde.org/multimedia/haruna) (KDE's mpv-based
video player) for a floating, chromeless video window on KDE Plasma /
SteamOS desktop mode.

Two additions over Haruna:

- **Chromeless mode.** No title bar, header, menu bar or docked footer — just
  the video and Haruna's floating controls. Drag anywhere to move the window,
  drag the edges to resize; it stays a normal KWin window (rules, tiling,
  Meta+drag, virtual desktops all work).
- **Crop to content.** Pause, drag a box around the real picture, and the
  player crops the video to it and resizes the window to match, so the
  floating window *is* the content.

Everything else is unmodified Haruna and the fork tracks upstream `master`.
See [`docs/PLAN.md`](docs/PLAN.md) for the design and status.

## Build (Flatpak)

SteamOS has a read-only root, so Float Frame is built and run as a Flatpak
using the `org.flatpak.Builder` Flatpak and the KDE 6.11 runtime.

```sh
flatpak/build.sh                                          # build + install for the current user
flatpak run io.github.python2121.FloatFrame               # run
flatpak run io.github.python2121.FloatFrame --chromeless  # start without any chrome
```

It installs as its own app (id `io.github.python2121.FloatFrame`, "Float
Frame" in the launcher) and coexists with Flathub's Haruna. It starts
chromeless; `Ctrl+Shift+F` (or the hamburger menu → View) brings the window
frame, menu bar and toolbar back, and the setting is remembered.

The manifest is derived from Flathub's `org.kde.haruna` manifest and builds
libmpv, mpvqt and friends from source; the first build takes a while, later
ones are cached.

## Upstream

```sh
git fetch upstream
git rebase upstream/master   # on main
```

Haruna is © George Florea Bănuș and contributors, GPL-3.0-or-later; see
`LICENSES/` and the upstream README in the git history.
