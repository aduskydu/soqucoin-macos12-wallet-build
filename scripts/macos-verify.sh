#!/usr/bin/env bash
# Checks on the built binaries (run on the macOS build runner).
# Usage: [ARCH=x86_64|arm64] [MACOSX_DEPLOYMENT_TARGET=12.0] scripts/macos-verify.sh <soqucoin source dir>
# Note: every command output is captured into a variable before grep: with pipefail, `prog | grep -q` can fail at
# random (grep exits at the first match, prog gets SIGPIPE, the pipeline reports 141).
set -euo pipefail
SRC=$(cd "$1" && pwd)
D=$SRC/src/soqucoind
C=$SRC/src/soqucoin-cli
ARCH=${ARCH:-x86_64}
MIN=${MACOSX_DEPLOYMENT_TARGET:-12.0}

echo "::group::official macOS release checks ($ARCH, minos $MIN, system libraries only, runs without /usr/local + /opt/homebrew)"
bash "$SRC/.github/scripts/check-macos-release.sh" "$ARCH" "$MIN" "$D" "$C"
otool -L "$D" "$C"
vtool -show-build "$D" | sed -n '1,12p'
echo "::endgroup::"

echo "::group::nothing newer than macOS $MIN: no weak imports (a symbol newer than the deployment target is weak-linked and is NULL on $MIN)"
for bin in "$D" "$C"; do
  syms=$(nm -m "$bin")
  weak=$(grep -E '\(undefined\) weak external' <<<"$syms" || true)
  if [ -n "$weak" ]; then echo "$weak"; echo "$bin has weak imports - API newer than macOS $MIN?" >&2; exit 1; fi
  echo "$bin: no weak imports"
done
echo "::endgroup::"

if [ "$ARCH" = arm64 ]; then
  # Apple Silicon refuses to run an arm64 binary without a code signature. The linker signs it ad hoc
  # ("linker-signed"); anything that rewrote the file afterwards would break that.
  echo "::group::arm64: code signature present and valid"
  for bin in "$D" "$C"; do
    codesign --verify --strict --verbose=2 "$bin"
    info=$(codesign -dv "$bin" 2>&1)
    grep -E '^(Format|CodeDirectory|Signature)' <<<"$info" || true
  done
  echo "::endgroup::"
fi

echo "::group::wallet compiled in, ZMQ left out"
HELP=$("$D" -help)
grep -q -- '-disablewallet' <<<"$HELP" || { echo "soqucoind -help does not list -disablewallet: wallet not compiled in" >&2; exit 1; }
grep -q -- '-keypool' <<<"$HELP" || { echo "soqucoind -help does not list -keypool" >&2; exit 1; }
if grep -q -- '-zmqpubhashblock' <<<"$HELP"; then echo "ZMQ is compiled in (should be off)" >&2; exit 1; fi
"$D" -version | head -1
echo "::endgroup::"

# Instruction lines of one function, from its address to the next symbol's (same method as the official release check).
disasm_of() {  # binary symbol
  local bin=$1 sym=$2 syms end dis
  syms=$(nm -n "$bin")
  if ! read -r _ end < <(awk -v s="$sym" '$3 == s {a = $1; next} a != "" && $1 "" != a "" {print a, $1; exit}' <<<"$syms"); then
    return 1
  fi
  dis=$(otool -tV -p "$sym" "$bin")
  awk -v end="$end" '$1 !~ /^[0-9a-f]+$/ {next} $1 "" >= end "" {exit} {print}' <<<"$dis"
}

echo "::group::key generation uses the node's strong RNG (GetStrongRandBytes)"
# getnewaddress: CWallet::GenerateNewKey -> CKey::MakeNewKey(bool), which draws its seed from GetStrongRandBytes.
dsyms=$(nm "$D")   # captured first: nm | awk '{...; exit}' breaks nm's pipe (LLVM ERROR: Broken pipe) under pipefail
mk=$(awk '$3 == "__ZN4CKey10MakeNewKeyEb" {print $3; exit}' <<<"$dsyms")
if [ -n "$mk" ]; then
  d=$(disasm_of "$D" "$mk") || { echo "could not locate CKey::MakeNewKey" >&2; exit 1; }
  grep -q 'GetStrongRandBytes' <<<"$d" || { echo "CKey::MakeNewKey does not call GetStrongRandBytes" >&2; exit 1; }
  echo "CKey::MakeNewKey -> GetStrongRandBytes OK"
else
  echo "::warning::CKey::MakeNewKey symbol not found (inlined?); relying on the wallet smoke test's distinct-keys check"
fi
# pqcrystals keypair (CDilithiumKey, PQKeyPair::Generate) calls randombytes: it must be the node's own
# (src/pat/randombytes.cpp -> GetStrongRandBytes), not crypto/dilithium/randombytes.c or libsodium's. Copied from the
# official release check (soqucoin .github/workflows/release.yml, build-macos, "Verify binaries").
for bin in "$D" "$C"; do
  syms=$(nm -n "$bin")
  if awk '$3 == "_randombytes"' <<<"$syms" | grep -q .; then
    d=$(disasm_of "$bin" _randombytes) || { echo "$bin: _randombytes found but no symbol after it" >&2; exit 1; }
    grep -q 'GetStrongRandBytes' <<<"$d" || { echo "$bin: randombytes does not call GetStrongRandBytes" >&2; exit 1; }
    echo "$bin: randombytes -> GetStrongRandBytes OK"
  elif [ "$bin" = "$D" ]; then
    echo "$D: no _randombytes symbol at all" >&2; exit 1
  fi
done
# Nothing from libsodium may be linked in (ZMQ is off, so nothing needs it).
syms=$(nm "$D")
if grep -qE ' _sodium_init$| _crypto_sign_ed25519' <<<"$syms"; then echo "libsodium symbols found in soqucoind" >&2; exit 1; fi
echo "no libsodium"
echo "::endgroup::"
