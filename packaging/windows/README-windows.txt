Soqucoin Core v2.5.2 (official source, commit 35b38fce) with the wallet, for Windows x64.
Built from the official source by this repository's GitHub Actions run, the same way as the official Windows package,
but stand-alone (no extra DLLs) and run-tested on Windows before upload (new address, backup, mine to it, spend it).
Command-line only (soqucoind.exe + soqucoin-cli.exe), no graphical wallet.

1. Unzip, open the folder, type cmd in the address bar and press Enter.
2. Start the node and leave that window open (it prints nothing; that is normal; first start creates the wallet,
   no need to wait for it to sync):
     .\soqucoind.exe
3. Open a second cmd window in the same folder. New receiving address (sq1p..., 62 characters, lowercase;
   do not add arguments):
     .\soqucoin-cli.exe getnewaddress
   "Could not locate RPC credentials", "couldn't connect to server" or "error code: -28" just mean the node is still
   starting; wait a few seconds and run it again.
4. Back up the wallet right away (file name only):
     .\soqucoin-cli.exe backupwallet soq-wallet-backup.dat
   Nothing is printed on success. The backup lands in %APPDATA%\Soqucoin\backups\ (paste that into the Explorer
   address bar). Copy it to a USB stick or another computer. The wallet itself is %APPDATA%\Soqucoin\wallet.dat.
   This wallet has no recovery phrase and does not derive keys from a seed: a backup only holds the keys that existed
   when it was made. Make a NEW backup (new file name, e.g. soq-wallet-2.dat) after every getnewaddress and after every
   payment you send (change goes to a new key), and keep the latest copy off this computer. If the wallet and every
   backup are lost, the coins are lost. The backup file is the private key - never send it to anyone.
5. Stop the node when done (receiving does not need it running):
     .\soqucoin-cli.exe stop

SHA256SUMS.txt is in the same download as this package.
