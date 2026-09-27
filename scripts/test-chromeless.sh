#!/usr/bin/env bash
# Smoke-test the installed Float Frame flatpak on KDE Plasma/Wayland without a human:
# launch it with the given arguments on a generated letterboxed test clip, ask KWin
# (via a scripting D-Bus call) for the window's frame vs client geometry — equal sizes
# mean no server-side decoration, i.e. chromeless worked — then close it.
#
#   scripts/test-chromeless.sh default               # chromeless is the default: expect frame == client
#   scripts/test-chromeless.sh flag --chromeless     # expect frame == client
#   (write Chromeless=false to the sandbox's haruna.conf for a framed run: frame > client)
#
# Only the fork is touched: the KWin script matches the test clip's caption and
# `flatpak kill` targets the fork's app id, so a running Haruna is left alone.
set -u
APP=io.github.python2121.FloatFrame
if flatpak ps --columns=application 2>/dev/null | grep -q "$APP"; then
    echo "$APP is already running; refusing (cleanup would close that window too)" >&2
    exit 3
fi
HERE=$(cd "$(dirname "$0")" && pwd)
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/float-frame
CLIP=$CACHE/letterbox-test.mp4
JS=$HERE/kwin-inspect.js
NAME=${1:?usage: $0 <run-name> [app args...]}; shift
LOG=$CACHE/run-$NAME.log

mkdir -p "$CACHE"
if [ ! -f "$CLIP" ]; then
    # 640x360 test pattern letterboxed into 640x480: black bars for Phase 3 crop tests
    flatpak run --filesystem=home --command=sh org.kde.Sdk//6.11 -c \
        "ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=size=640x360:rate=30 -t 8 \
         -vf 'pad=640:480:0:60:black' -pix_fmt yuv420p -y '$CLIP'"
fi

echo "### launch: flatpak run $APP $* $CLIP"
flatpak run "$APP" "$@" "$CLIP" >"$LOG" 2>&1 &
sleep 7
ID=$(busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting loadScript s "$JS" | awk '{print $2}')
busctl --user call org.kde.KWin "/Scripting/Script$ID" org.kde.kwin.Script run >/dev/null
sleep 1
journalctl --user -b --since '10s ago' -o cat | grep FLOATFRAME-INSPECT
busctl --user call org.kde.KWin /Scripting org.kde.kwin.Scripting unloadScript s "$JS" >/dev/null
flatpak kill "$APP" 2>/dev/null; sleep 1
flatpak ps --columns=application 2>/dev/null | grep -q "$APP" && echo "WARNING: $APP still running" || echo "### closed"
grep -iE 'error|warning|TypeError|ReferenceError|is not a function|Unable to assign' "$LOG" \
    | grep -vE 'MESA|libEGL|libcuda|qt.qpa|Metadata not found' | head -10
