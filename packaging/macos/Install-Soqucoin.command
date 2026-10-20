#!/bin/bash
# 把 soqucoind / soqucoin-cli 装到 ~/Soqucoin(不需要管理员密码),去掉下载带来的隔离标记,再打开一个终端窗口到那里。
# Installs soqucoind / soqucoin-cli into ~/Soqucoin (no admin password), clears the download quarantine flag, opens Terminal there.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${SOQ_INSTALL_DIR:-$HOME/Soqucoin}"
mkdir -p "$DEST"
cp -f "$SRC/soqucoind" "$SRC/soqucoin-cli" "$DEST/"
cp -f "$SRC/使用说明.txt" "$SRC/README-macos12.txt" "$DEST/" 2>/dev/null || true
chmod +x "$DEST/soqucoind" "$DEST/soqucoin-cli"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
"$DEST/soqucoind" -version | head -1
echo
echo "已装到 / Installed to: $DEST"
echo "下一步看 / Next: $DEST/使用说明.txt"
if [ -z "${SOQ_INSTALL_NO_TERMINAL:-}" ]; then
  open -a Terminal "$DEST" || true
fi
