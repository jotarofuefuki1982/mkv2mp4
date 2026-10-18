#!/usr/bin/env bash
# Install (or uninstall) mkv2mp4 on Arch or Ubuntu/Debian.
#   sudo ./install.sh              install to /usr/local/bin, pulling in ffmpeg + python
#   sudo ./install.sh --no-deps    skip the package manager
#   sudo ./install.sh --uninstall
#   PREFIX=$HOME/.local ./install.sh --no-deps    per-user install, no sudo
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
deps=1
action=install

for arg in "$@"; do
    case "$arg" in
        --no-deps) deps=0 ;;
        --uninstall) action=uninstall ;;
        -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

need_root() {
    if [[ $EUID -ne 0 && ! -w "$PREFIX" ]]; then
        exec sudo env PREFIX="$PREFIX" "$0" "$@"
    fi
}

if [[ $action == uninstall ]]; then
    need_root "$@"
    rm -f "$PREFIX/bin/mkv2mp4" "$PREFIX/share/man/man1/mkv2mp4.1"
    echo "removed $PREFIX/bin/mkv2mp4 and its man page"
    exit 0
fi

if [[ $deps -eq 1 ]]; then
    if [[ $EUID -ne 0 ]]; then exec sudo env PREFIX="$PREFIX" "$0" "$@"; fi
    if command -v pacman >/dev/null; then
        pacman -S --needed --noconfirm ffmpeg python
    elif command -v apt-get >/dev/null; then
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg python3
    else
        echo "warning: unknown package manager, make sure ffmpeg and python3 are installed" >&2
    fi
fi

need_root "$@"
install -Dm755 "$HERE/mkv2mp4" "$PREFIX/bin/mkv2mp4"
install -Dm644 "$HERE/mkv2mp4.1" "$PREFIX/share/man/man1/mkv2mp4.1"
command -v mandb >/dev/null && mandb -q 2>/dev/null || true
echo "installed $PREFIX/bin/mkv2mp4 ($("$PREFIX/bin/mkv2mp4" --version))"
