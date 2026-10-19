Soqucoin Core v2.5.2 (official source, commit 35b38fce) with the WALLET, for Intel Macs, macOS 12 Monterey or later.
Built from the official source by this repository's GitHub Actions run; the official macOS packages leave the wallet out
and need macOS 15. Command-line only (soqucoind + soqucoin-cli), no graphical wallet.

1. Unpack, open Terminal, go into the folder:
     cd ~/Downloads/soqucoin-v2.5.2-macos12-x64-wallet
   Downloaded files are quarantined by macOS; clear that for this folder once (otherwise macOS refuses to run them):
     xattr -dr com.apple.quarantine .
2. Start the node (first start creates the wallet; you do not need to wait for it to sync):
     ./soqucoind -daemon
3. New receiving address (sq1p..., 62 characters, all lowercase; do not add arguments):
     ./soqucoin-cli getnewaddress
   "Could not locate RPC credentials", "couldn't connect to server" or "error code: -28" just mean the node is still
   starting; wait a few seconds and run it again.
4. Back up the wallet right away (file name only):
     ./soqucoin-cli backupwallet soq-wallet-backup.dat
   Nothing is printed on success. The backup lands in
     ~/Library/Application Support/Soqucoin/backups/
   Copy it to a USB stick or another computer. The wallet itself is ~/Library/Application Support/Soqucoin/wallet.dat.
   This wallet has no recovery phrase: if the wallet and every backup are lost, the coins are lost. The backup file
   is the private key - never send it to anyone.
5. Stop the node when done (receiving does not need it running):
     ./soqucoin-cli stop

Files: soqucoind, soqucoin-cli (x86_64 only, minimum macOS 12.0, statically linked against OpenSSL 3.6.3,
Boost 1.92.0, libevent 2.1.13, Berkeley DB 5.3.28; ZMQ and UPnP left out). SHA256SUMS.txt is in the same
download as this package.
