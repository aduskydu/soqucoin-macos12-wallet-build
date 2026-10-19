# soqucoin-macos12-wallet-build

(Also: **build-windows** — the Windows x64 wallet build, same recipe as the official release, stand-alone and run-tested on a Windows runner.)

Builds **Soqucoin Core v2.5.2** (official source, tag `v2.5.2`, commit `35b38fce`) **with the wallet** for **Intel Macs running macOS 12 or later**.
The official macOS packages are built with `--disable-wallet` and for macOS 15, so they cannot create addresses and do not start on macOS 12.

Run the workflow **build** (Actions → build → Run workflow). It:
- builds OpenSSL 3.6.3, Boost 1.92.0, libevent 2.1.13 and Berkeley DB 5.3.28 from source (pinned SHA-256) for macOS 12.0, x86_64, static;
- builds soqucoind + soqucoin-cli with the wallet on and ZMQ / UPnP / GUI off;
- runs the official `check-macos-release.sh` (x86_64, minos 12.0, system libraries only), the official ML-DSA `randombytes → GetStrongRandBytes` check, and a regtest wallet test (new sq1p address, backup, mine to it, spend it);
- uploads `soqucoin-v2.5.2-macos12-x64-wallet.tar.gz` + `SHA256SUMS.txt`. Usage: see `README-macos12.txt`.
