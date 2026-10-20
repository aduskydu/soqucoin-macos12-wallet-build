#!/bin/bash
# Installs soqucoind / soqucoin-cli into ~/Soqucoin (no admin password), clears the download quarantine flag,
# and opens a Terminal window in that folder.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${SOQ_INSTALL_DIR:-$HOME/Soqucoin}"
mkdir -p "$DEST"
# Remove before copying: on Apple Silicon, overwriting an already-run signed binary in place keeps the old
# signature cached for that file and the new one gets killed ("Killed: 9"). A fresh file avoids that.
rm -f "$DEST/soqucoind" "$DEST/soqucoin-cli"
cp "$SRC/soqucoind" "$SRC/soqucoin-cli" "$DEST/"
NOTES=README
for f in "$SRC"/README-macos*.txt; do
  [ -e "$f" ] || continue
  cp -f "$f" "$DEST/" && NOTES=$(basename "$f")
done
chmod +x "$DEST/soqucoind" "$DEST/soqucoin-cli"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
"$DEST/soqucoind" -version | head -1
echo
echo "Installed to: $DEST"
echo "Next: read $DEST/$NOTES (Chinese instructions are under Notes at the end of that file)"
if [ -z "${SOQ_INSTALL_NO_TERMINAL:-}" ]; then
  open -a Terminal "$DEST" || true
fi
