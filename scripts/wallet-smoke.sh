#!/usr/bin/env bash
# Wallet smoke test on regtest (runs on the macOS or Windows build runner; nothing leaves the runner).
# What it proves: the wallet starts from scratch, getnewaddress gives a 62-char sq1p address, backupwallet writes into
# <datadir>/regtest/backups, and coins mined to a wallet sq1p address can be SPENT by the wallet (the Dilithium
# witness-v1 signing path) — nobody had run that on a release binary before.
# Usage: scripts/wallet-smoke.sh <soqucoind> <soqucoin-cli>      (on Windows: the .exe paths, run from Git Bash)
set -euo pipefail
D=$1
C=$2
DATA=$(mktemp -d)
DATADIR=$DATA
if command -v cygpath >/dev/null 2>&1; then DATADIR=$(cygpath -w "$DATA"); fi   # Windows: native path for the node
# Windows prints CRLF; strip CR from every answer.
cli() { "$C" -regtest -datadir="$DATADIR" "$@" | tr -d '\r'; }
cleanup() { "$C" -regtest -datadir="$DATADIR" stop >/dev/null 2>&1 || true; sleep 5; kill "$PID" 2>/dev/null || true; }

"$D" -regtest -datadir="$DATADIR" -daemon=0 -printtoconsole=0 -listen=0 -keypool=10 &
PID=$!
trap cleanup EXIT
up=0
for i in $(seq 1 180); do
  if cli getblockchaininfo >/dev/null 2>&1 && cli getwalletinfo >/dev/null 2>&1; then up=1; break; fi
  kill -0 "$PID" 2>/dev/null || { echo "soqucoind exited during start-up" >&2; tail -40 "$DATA/regtest/debug.log" >&2 || true; exit 1; }
  sleep 1
done
[ "$up" = 1 ] || { echo "soqucoind did not answer within 180 s" >&2; tail -40 "$DATA/regtest/debug.log" >&2 || true; exit 1; }
cli getwalletinfo

A=$(cli getnewaddress)
echo "new address: $A"
[[ "$A" =~ ^sq1p[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{58}$ ]] || { echo "getnewaddress did not return a 62-char lowercase sq1p address" >&2; exit 1; }
cli validateaddress "$A"
cli validateaddress "$A" | grep -q '"isvalid": true' || { echo "validateaddress: not valid" >&2; exit 1; }

cli backupwallet smoke-backup.dat
test -s "$DATA/regtest/backups/smoke-backup.dat" || { echo "backup not found in <datadir>/regtest/backups/" >&2; ls -la "$DATA/regtest" >&2; exit 1; }
echo "backup written: $(ls -la "$DATA/regtest/backups/smoke-backup.dat")"
if cli backupwallet smoke-backup.dat >/dev/null 2>&1; then echo "second backupwallet with the same name should refuse to overwrite" >&2; exit 1; fi

# Regtest: legacy blocks below height 20, AuxPoW required from 20 (auxpowConsensus.nHeightEffective), coinbase maturity 60.
cli generatetoaddress 19 "$A" >/dev/null
cli generatetoaddress 81 "$A" 1000000 1 >/dev/null
echo "height: $(cli getblockcount)"
BAL=$(cli getbalance)
echo "balance after 100 blocks: $BAL"
awk -v b="$BAL" 'BEGIN { exit !(b + 0 > 0) }' || { echo "mined coinbase to the wallet's sq1p address is not counted as spendable balance" >&2; exit 1; }

B=$(cli getnewaddress)
TX=$(cli sendtoaddress "$B" 1)
echo "spend tx: $TX"
cli generatetoaddress 1 "$A" 1000000 1 >/dev/null
CONF=$(cli gettransaction "$TX" | sed -n 's/.*"confirmations": *\([0-9-]*\).*/\1/p' | head -1)
echo "confirmations: $CONF"
[ "${CONF:-0}" -ge 1 ] || { echo "spend did not confirm" >&2; exit 1; }
GOT=$(cli getreceivedbyaddress "$B" 1)
echo "received by B: $GOT"
case "$GOT" in 1|1.0|1.00000000) ;; *) echo "B did not receive 1 SOQ (got $GOT)" >&2; exit 1 ;; esac
echo "wallet smoke test OK: address, backup, mined sq1p coinbase spent and confirmed"
