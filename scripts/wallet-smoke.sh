#!/usr/bin/env bash
# Wallet smoke test on regtest (runs on the macOS or Windows build runner; nothing leaves the runner).
# Proves, on the release binaries themselves:
#   1. a fresh wallet starts, getnewaddress gives a 62-char lowercase sq1p (Dilithium, witness v1) address that is ours;
#   2. backupwallet writes <datadir>/regtest/backups/<name> and refuses to overwrite it;
#   3. coins mined to that sq1p address count as balance and can be SPENT (Dilithium witness-v1 signing), confirmed;
#   4. the BACKUP restores: a node started on a copy of the backup owns the address, shows the same balance and can spend;
#   5. a second, brand-new wallet (new process) gets a DIFFERENT first address — catches a fixed-seed key generator,
#      which would hand every user the same private keys.
# Usage: scripts/wallet-smoke.sh <soqucoind> <soqucoin-cli>      (on Windows: the .exe paths, run from Git Bash)
set -euo pipefail
D=$1
C=$2
DATA=$(mktemp -d)
DATADIR=$DATA
if command -v cygpath >/dev/null 2>&1; then DATADIR=$(cygpath -w "$DATA"); fi   # Windows: native path for the node
LOG=$DATA/regtest/debug.log
PID=
cli() { "$C" -regtest -datadir="$DATADIR" "$@" | tr -d '\r'; }   # Windows prints CRLF
fail() { echo "FAIL: $*" >&2; tail -60 "$LOG" >&2 2>/dev/null || true; exit 1; }
stop_node() {
  [ -n "$PID" ] || return 0
  "$C" -regtest -datadir="$DATADIR" stop >/dev/null 2>&1 || true
  for _ in $(seq 1 60); do kill -0 "$PID" 2>/dev/null || break; sleep 1; done
  kill "$PID" 2>/dev/null || true
  wait "$PID" 2>/dev/null || true
  PID=
}
trap stop_node EXIT
start_node() {   # extra soqucoind args
  "$D" -regtest -datadir="$DATADIR" -daemon=0 -printtoconsole=0 -listen=0 -keypool=10 "$@" &
  PID=$!
  for _ in $(seq 1 180); do
    if cli getblockchaininfo >/dev/null 2>&1 && cli getwalletinfo >/dev/null 2>&1; then return 0; fi
    kill -0 "$PID" 2>/dev/null || fail "soqucoind $* exited during start-up"
    sleep 1
  done
  fail "soqucoind $* did not answer within 180 s"
}
blocks() {   # n address -> mine n blocks to address and check that exactly n were made
  local n=$1 addr=$2 before after
  before=$(cli getblockcount)
  cli generatetoaddress "$n" "$addr" >/dev/null || fail "generatetoaddress $n"
  after=$(cli getblockcount)
  [ "$after" -eq $((before + n)) ] || fail "asked for $n blocks, height went $before -> $after"
}
ismine() { cli validateaddress "$1" | grep -q '"ismine": true'; }
is_sq1p() { [[ "$1" =~ ^sq1p[qpzry9x8gf2tvdw0s3jn54khce6mua7l]{58}$ ]]; }
spend() {   # to amount -> send, check it entered the mempool, mine 1 block, check it confirmed
  local to=$1 amt=$2 tx conf
  tx=$(cli sendtoaddress "$to" "$amt") || fail "sendtoaddress $to $amt"
  echo "spend tx: $tx"
  cli getmempoolentry "$tx" >/dev/null || fail "tx $tx did not enter the mempool"
  blocks 1 "$A"
  conf=$(cli gettransaction "$tx" | sed -n 's/.*"confirmations": *\([0-9-]*\).*/\1/p' | head -1)
  [ "${conf:-0}" -ge 1 ] || fail "tx $tx not confirmed (confirmations=$conf)"
}

echo "== 1. fresh wallet, new address"
start_node
cli getwalletinfo
A=$(cli getnewaddress)
echo "address A: $A"
is_sq1p "$A" || fail "getnewaddress did not return a 62-char lowercase sq1p address: $A"
cli validateaddress "$A"
cli validateaddress "$A" | grep -q '"isvalid": true' || fail "A not valid"
ismine "$A" || fail "A not ismine"

echo "== 2. backup"
cli backupwallet smoke-backup.dat
test -s "$DATA/regtest/backups/smoke-backup.dat" || fail "backup not found in <datadir>/regtest/backups/"
ls -la "$DATA/regtest/backups/smoke-backup.dat"
if cli backupwallet smoke-backup.dat >/dev/null 2>&1; then fail "a second backupwallet with the same name should refuse to overwrite"; fi

echo "== 3. mine to A, spend"
blocks 100 "$A"
BAL=$(cli getbalance)
echo "balance after 100 blocks (maturity 60): $BAL"
awk -v b="$BAL" 'BEGIN { exit !(b + 0 > 0) }' || fail "coinbase mined to the wallet's sq1p address is not spendable balance"
B=$(cli getnewaddress)
echo "address B: $B"
is_sq1p "$B" || fail "B is not sq1p"
[ "$A" != "$B" ] || fail "two getnewaddress calls returned the same address"
spend "$B" 1
GOT=$(cli getreceivedbyaddress "$B" 1)
echo "received by B: $GOT"
case "$GOT" in 1|1.0|1.00000000) ;; *) fail "B did not receive 1 SOQ (got $GOT)" ;; esac
BAL0=$(cli getbalance)
echo "balance before restore test: $BAL0"
stop_node

echo "== 4. restore from the backup"
mv "$DATA/regtest/wallet.dat" "$DATA/regtest/wallet.orig.dat"
cp "$DATA/regtest/backups/smoke-backup.dat" "$DATA/regtest/wallet.dat"
start_node -rescan
ismine "$A" || fail "restored wallet does not own A"
ismine "$B" || fail "restored wallet does not own B (it was in the keypool at backup time)"
BAL1=$(cli getbalance)
echo "balance after restore + rescan: $BAL1"
[ "$BAL1" = "$BAL0" ] || fail "restored balance $BAL1 != $BAL0"
R=$(cli getnewaddress)
spend "$R" 0.5
echo "restored wallet can spend: OK"
stop_node

echo "== 5. a second brand-new wallet gets different keys"
start_node -wallet=fresh.dat
A2=$(cli getnewaddress)
echo "first address of the second wallet: $A2"
is_sq1p "$A2" || fail "A2 is not sq1p"
[ "$A2" != "$A" ] && [ "$A2" != "$B" ] || fail "a new wallet produced an address the first wallet already had - key generation is not random"
ismine "$A" && fail "the second wallet owns the first wallet's address"
stop_node

echo "wallet smoke test OK: new sq1p address, backup, mined coinbase spent, backup restores and spends, new wallets get new keys"
