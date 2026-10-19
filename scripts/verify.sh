#!/usr/bin/env bash
# Checks on the built binaries (run on the macOS build runner).
# Usage: scripts/verify.sh <soqucoin source dir>
set -euo pipefail
SRC=$(cd "$1" && pwd)
D=$SRC/src/soqucoind
C=$SRC/src/soqucoin-cli

echo "::group::official macOS release checks (x86_64, minos 12.0, system libraries only, runs without /usr/local + /opt/homebrew)"
bash "$SRC/.github/scripts/check-macos-release.sh" x86_64 12.0 "$D" "$C"
otool -L "$D" "$C"
vtool -show-build "$D" | sed -n '1,12p'
echo "::endgroup::"

echo "::group::wallet compiled in, ZMQ / UPnP left out"
"$D" -help | grep -q -- '-disablewallet' || { echo "soqucoind -help does not list -disablewallet: wallet not compiled in" >&2; exit 1; }
"$D" -help | grep -q -- '-keypool' || { echo "soqucoind -help does not list -keypool" >&2; exit 1; }
if "$D" -help | grep -q -- '-zmqpubhashblock'; then echo "ZMQ is compiled in (should be off)" >&2; exit 1; fi
"$D" -version | head -1
echo "::endgroup::"

echo "::group::ML-DSA key generation uses the node's own randombytes (GetStrongRandBytes) — same check as the official release"
# Copied from soqucoin .github/workflows/release.yml (build-macos, "Verify binaries"): the static link keeps whichever
# randombytes definition it loads first; the daemon must keep src/pat/randombytes.cpp, which calls GetStrongRandBytes.
for bin in "$D" "$C"; do
  if nm -n "$bin" | awk '$3 == "_randombytes"' | grep -q .; then
    if ! read -r _ end < <(nm -n "$bin" \
        | awk '$3 == "_randombytes" {s = $1; next} s != "" && $1 "" != s "" {print s, $1; exit}'); then
      echo "$bin: nm found _randombytes but no symbol after it" >&2; exit 1
    fi
    if ! otool -tV -p _randombytes "$bin" \
        | awk -v end="$end" '$1 !~ /^[0-9a-f]+$/ {next} $1 "" >= end "" {exit} {print}' \
        | grep -q 'GetStrongRandBytes'; then
      echo "$bin: randombytes does not call GetStrongRandBytes" >&2; exit 1
    fi
    echo "$bin: randombytes -> GetStrongRandBytes OK"
  elif [ "$bin" = "$D" ]; then
    echo "$D: no _randombytes symbol at all" >&2; exit 1
  fi
done
# Nothing from libsodium may be linked in (ZMQ is off, so nothing needs it).
if nm "$D" | grep -qE ' _sodium_init$| _crypto_sign_ed25519'; then echo "libsodium symbols found in soqucoind" >&2; exit 1; fi
echo "::endgroup::"
