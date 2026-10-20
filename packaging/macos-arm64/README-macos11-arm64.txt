Soqucoin Core v2.5.2 (official source, commit 35b38fce) with the WALLET, for Apple Silicon Macs (M1 and later),
macOS 11 Big Sur or later. For Intel Macs use the macos12-x64 package instead.
Built from the official source by this repository's GitHub Actions run; the official macOS packages leave the wallet out
and need macOS 15. Command-line only (soqucoind + soqucoin-cli), no graphical wallet.
(Chinese instructions: see Notes at the end of this file.)

A. Install
 With the installer (DMG):
  1. Open the DMG, Control-click "Install-Soqucoin.command", choose Open, then click Open again.
     A plain double-click is refused ("unidentified developer"); the Control-click is needed only the first time.
     On macOS 15 or later the Control-click no longer works: double-click it once and click Done, then within about
     an hour open System Settings > Privacy & Security, scroll down to Security, click "Open Anyway" and confirm with
     your Mac password.
  2. It copies the programs into a Soqucoin folder in your home folder and opens a Terminal window in that folder.
 Without the installer (or from the .tar.gz):
  1. Copy soqucoind and soqucoin-cli out of the DMG into a folder of your own (or unpack the .tar.gz).
  2. Open Terminal, type cd and a space, drag that folder into the Terminal window and press Enter
     (if the folder only holds another folder of the same name, go into that one).
  3. Downloaded files are quarantined by macOS; clear that for this folder once (otherwise macOS refuses to run them):
       xattr -dr com.apple.quarantine .

B. Receiving address (type these in that Terminal window)
1. Start the node (first start creates the wallet; you do not need to wait for it to sync):
     ./soqucoind -daemon
2. New receiving address (sq1p..., 62 characters, all lowercase; do not add arguments):
     ./soqucoin-cli getnewaddress
   "Could not locate RPC credentials", "couldn't connect to server" or "error code: -28" just mean the node is still
   starting; wait up to a minute and run it again.
3. Back up the wallet right away (file name only):
     ./soqucoin-cli backupwallet soq-wallet-backup.dat
   Nothing is printed on success; running it again with the same name reports "already exists", which means the
   backup is already there. The backup lands in
     ~/Library/Application Support/Soqucoin/backups/
   (in Finder press Shift+Command+G and paste that path). Copy it to a USB stick or another computer.
   The wallet itself is wallet.dat in ~/Library/Application Support/Soqucoin/; do not delete that folder.
   This wallet has no recovery phrase and does not derive keys from a seed: a backup only holds the keys that existed
   when it was made. Make a NEW backup (new file name, e.g. soq-wallet-2.dat) after every getnewaddress and after every
   payment you send (change goes to a new key), and keep the latest copy off this computer. If the wallet and every
   backup are lost, the coins are lost. The backup file is the private key - never send it to anyone.
4. Stop the node when done (receiving does not need it running):
     ./soqucoin-cli stop

Files: soqucoind, soqucoin-cli (arm64 only, ad-hoc signed by the linker, minimum macOS 11.0, statically linked against OpenSSL 3.6.3,
Boost 1.92.0, libevent 2.1.13, Berkeley DB 5.3.28; ZMQ and UPnP left out). SHA256SUMS.txt is in the same
download as this package.


Notes
=====
Other languages are added below. The English text above is the reference.

中文说明
--------
Soqucoin Core v2.5.2 钱包(Apple 芯片 Mac,M1 及以后,macOS 11 及以上;Intel Mac 请用 macos12-x64 那个包)。用官方 v2.5.2 源码编译,带钱包;官方的 macOS 包没带钱包、
要 macOS 15。只有命令行,没有图形界面。

一、安装
 用安装程序(DMG):
  1. 打开 DMG,按住 Control 点「Install-Soqucoin.command」,选「打开」,再点「打开」。
     直接双击会提示「来自身份不明的开发者」;按住 Control 点开只需要第一次。
     macOS 15 及以上按住 Control 点开不管用了:先双击一次,点「完成」,然后在大约一小时内打开「系统设置 > 隐私与安全性」,
     往下翻到「安全性」,点「仍要打开」,输入 Mac 登录密码确认。
  2. 它会把程序装到你主目录下的 Soqucoin 文件夹,并打开一个终端窗口,已经在这个文件夹里。
 不用安装程序(或用 .tar.gz):
  1. 把 soqucoind、soqucoin-cli 从 DMG 里拷到你自己的文件夹(或者解压 .tar.gz)。
  2. 打开终端,输入 cd 和一个空格,把那个文件夹拖进终端窗口,按回车
     (如果那个文件夹里只有一个同名文件夹,就再进那一层)。
  3. 下载来的文件被 macOS 打了隔离标记,在这个文件夹里清一次(不然 macOS 不让运行):
       xattr -dr com.apple.quarantine .

二、生成收款地址(在上面那个终端窗口里输入)
1. 启动节点(第一次启动会自动建好钱包,不用等同步完):
     ./soqucoind -daemon
2. 生成地址(后面别加参数):
     ./soqucoin-cli getnewaddress
   得到一个 sq1p 开头、62 位、全小写的地址。
   报「Could not locate RPC credentials」「couldn't connect to server」或「error code: -28」是节点还没起好,最多等一分钟再试。
3. 马上备份钱包(只写文件名):
     ./soqucoin-cli backupwallet soq-wallet-backup.dat
   成功时不显示任何内容;同一个文件名再跑一次会报 already exists,说明已经备份好了。
   备份文件在「~/Library/Application Support/Soqucoin/backups/」(访达里按 Shift+Command+G,粘贴这串路径),
   把它拷到 U 盘或另一台电脑上存好。钱包本体是「~/Library/Application Support/Soqucoin/」里的 wallet.dat,别删这个文件夹。
   这个钱包没有助记词,也不是从种子推出钥匙的:备份里只有备份那一刻已有的钥匙。
   以后每次生成新地址、每次往外转币(找零会用新钥匙)之后,都要再备份一次,换个新文件名(比如 soq-wallet-2.dat),
   把最新的一份拷走。钱包和所有备份都丢了,币就取不回来。备份文件等于私钥,不要发给任何人。
4. 用完关掉节点(收款不需要它一直开着):
     ./soqucoin-cli stop
