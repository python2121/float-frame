#!/usr/bin/env bash
# Build Float Frame as a Flatpak from this checkout and install it for the
# current user. Uses the org.flatpak.Builder Flatpak so nothing needs to be
# installed on the (read-only) SteamOS root.
#
#   flatpak/build.sh            # build + install
#   flatpak/build.sh --no-install
#   flatpak run io.github.python2121.FloatFrame
set -euo pipefail

cd "$(dirname "$0")"
APP_ID=io.github.python2121.FloatFrame
MANIFEST="$APP_ID.yml"

INSTALL=(--install)
for arg in "$@"; do
    case "$arg" in
        --no-install) INSTALL=() ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

if ! flatpak info --user org.flatpak.Builder >/dev/null 2>&1 \
   && ! flatpak info org.flatpak.Builder >/dev/null 2>&1; then
    echo "installing org.flatpak.Builder" >&2
    flatpak install --user -y flathub org.flatpak.Builder
fi

mkdir -p build .flatpak-builder
exec flatpak run org.flatpak.Builder \
    --user "${INSTALL[@]}" \
    --install-deps-from=flathub \
    --force-clean --ccache \
    --state-dir=.flatpak-builder \
    --repo=repo \
    build "$MANIFEST"
