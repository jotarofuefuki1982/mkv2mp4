#!/usr/bin/env bash
# Build dist/mkv2mp4_<version>_all.deb, then install it with:
#   sudo apt install ./dist/mkv2mp4_<version>_all.deb
# (apt pulls in ffmpeg and python3 automatically.)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$ROOT/mkv2mp4")"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

install -Dm755 "$ROOT/mkv2mp4" "$STAGE/usr/bin/mkv2mp4"
install -Dm644 "$ROOT/mkv2mp4.1" "$STAGE/usr/share/man/man1/mkv2mp4.1"
gzip -9n "$STAGE/usr/share/man/man1/mkv2mp4.1"
install -Dm644 "$ROOT/README.md" "$STAGE/usr/share/doc/mkv2mp4/README.md"
install -Dm644 "$ROOT/LICENSE" "$STAGE/usr/share/doc/mkv2mp4/copyright"

mkdir -p "$STAGE/DEBIAN"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: mkv2mp4
Version: $VERSION
Section: video
Priority: optional
Architecture: all
Depends: python3 (>= 3.8), ffmpeg
Suggests: mesa-va-drivers, intel-media-va-driver
Installed-Size: $(du -sk "$STAGE/usr" | cut -f1)
Maintainer: Jotaro Fuefuki <343397152+jotarofuefuki1982@users.noreply.github.com>
Description: Convert MKV files into MP4s that every Jellyfin client can direct play
 Scans a directory for .mkv files and writes H.264/AAC MP4s to a destination
 directory, copying streams that are already compatible and re-encoding the
 rest. Originals are renamed to <name>.converted.mkv, never deleted.
EOF

mkdir -p "$ROOT/dist"
OUT="$ROOT/dist/mkv2mp4_${VERSION}_all.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$OUT"
echo "built $OUT"
