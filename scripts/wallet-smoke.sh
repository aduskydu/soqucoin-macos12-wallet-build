#!/usr/bin/env bash
# Wallet smoke test on regtest (run on the macOS build runner; nothing leaves the runner).
# What it proves: the wallet starts from scratch, getnewaddress gives a 62-char sq1p address, backupwallet writes into
# <datadir>/<chain>/backups, and coins mined to a wallet sq1p address can be SPENT by the wallet (the Dilithium
# witness-v1 signing path) — nobody had run that on a release binary before.
# Usage: scripts/wallet-smoke.sh <soqucoin source dir>
set -euo pipefail
SRC=$(cd "$1" && pwd)
D=$SRC/src/soqucoind
C=$SRC/src/soqucoin-cli
DATA=$(mktemp -d)
cli() { "$C" -regtest -datadir="$DATA" "$@"; }
cleanup() { cli stop >/dev/null 2>&1 || true; sleep 3; kill "$PID" 2>/dev/null || true; }

"$D" -regtest -datadir="$DATA" -daemon=0 -printtoconsole=0 -listen=0 -keypool=10 &
PID=$!
trap cleanup EXIT
for i in $(seq 1 120); do
  if cli getblockchaininfo >/dev/null 2>&1 && cli getwalletinfo >/dev/null 2>&1; then break; fi
  kill -0 "$PID" 2>/dev/null || { echo "soqucoind exited during start-up" >&2; tail -40 "$DATA/regtest/debug.log" >&2 || true; exit 1; }
  sleep 1
done
cli getwalletinfo

A=$(cli getnewaddress)
echo "new address: $A"
[[ "$A" =~ ^sq1p[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{58}$ ]] || { echo "getnewaddress did not return a 62-char lowercase sq1p address" >&2; exit 1; }
cli validateaddress "$A"
cli validateaddress "$A" | grep -q '"isvalid": true' || { echo "validateaddress: not valid" >&2; exit 1; }

cli backupwallet smoke-backup.dat
test -s "$DATA/regtest/backups/smoke-backup.dat" || { echo "backup not found in <datadir>/regtest/backups/" >&2; ls -la "$DATA/regtest" >&2; exit 1; }
echo "backup written: $(ls -la "$DATA/regtest/backups/smoke-backup.dat")"
if cli backupwallet smoke-backup.dat 2>/dev/null; then echo "second backupwallet with the same name should refuse to overwrite" >&2; exit 1; fi

# Regtest: legacy blocks below height 20, AuxPoW required from 20 (auxpowConsensus.nHeightEffective), coinbase maturity 60.
cli generatetoaddress 19 "$A" >/dev/null
cli generatetoaddress 81 "$A" 1000000 1 >/dev/null
echo "height: $(cli getblockcount)"
BAL=$(cli getbalance)
echo "balance after 100 blocks: $BAL"
python3 -c "import sys; sys.exit(0 if float('$BAL') > 0 else 1)" || { echo "mined coinbase to the wallet's sq1p address is not counted as spendable balance" >&2; exit 1; }

B=$(cli getnewaddress)
TX=$(cli sendtoaddress "$B" 1)
echo "spend tx: $TX"
cli generatetoaddress 1 "$A" 1000000 1 >/dev/null
CONF=$(cli gettransaction "$TX" | python3 -c "import json,sys; print(json.load(sys.stdin)['confirmations'])")
echo "confirmations: $CONF"
[ "$CONF" -ge 1 ] || { echo "spend did not confirm" >&2; exit 1; }
GOT=$(cli getreceivedbyaddress "$B" 1)
python3 -c "import sys; sys.exit(0 if abs(float('$GOT') - 1) < 1e-8 else 1)" || { echo "B did not receive 1 SOQ (got $GOT)" >&2; exit 1; }
echo "wallet smoke test OK: address, backup, mined sq1p coinbase spent and confirmed"
