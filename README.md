# soqucoin-wallet-build

用官方源码编译带钱包的 **Soqucoin Core v2.5.2**:**Intel Mac(macOS 12 及以上,DMG)** 和 **Windows x64**。
Builds **Soqucoin Core v2.5.2 with the wallet** from the official source, for **Intel Macs (macOS 12+, DMG)** and **Windows x64**.

为什么要自己编 / Why: 官方 v2.5.2 的 macOS 包编译时关掉了钱包,而且要 macOS 15;官方 Windows 包带钱包,但官方流程没有在 Windows 上实际运行过。
The official v2.5.2 macOS packages are built without the wallet and need macOS 15; the official Windows package has the wallet, but the official pipeline never runs it on Windows.

只有命令行程序(`soqucoind` + `soqucoin-cli`),没有图形界面;产物没有签名。
Command-line programs only (`soqucoind` + `soqucoin-cli`), no GUI; the binaries are not signed.

## 怎么编的 / How it is built

- 源码 / Source: [soqucoin/soqucoin](https://github.com/soqucoin/soqucoin) tag `v2.5.2`, commit `35b38fce` — 每次构建都核对 / checked on every run.
- **macOS** — `.github/workflows/build-macos.yml`,GitHub `macos-15-intel`,Xcode 16.4:
  OpenSSL 3.6.3、Boost 1.92.0、libevent 2.1.13、Berkeley DB 5.3.28 全部从源码编(源码包 SHA-256 固定),目标 macOS 12.0、x86_64、静态链接;钱包开,ZMQ / UPnP / GUI 关。
  All libraries built from source (pinned SHA-256) for macOS 12.0, x86_64, static; wallet on, ZMQ / UPnP / GUI off.
- **Windows** — `.github/workflows/build-windows.yml`,在 `ubuntu-22.04` 上交叉编译 / cross-compiled on `ubuntu-22.04`:
  照官方 release 的配方(`depends/`、mingw-w64 POSIX 线程),另加 `--disable-shared`,得到不依赖额外 DLL 的 exe。
  Same recipe as the official release (`depends/`, mingw-w64 POSIX threads) plus `--disable-shared`, so the .exe files need no extra DLLs.

## 检查与实测 / Checks and tests

- macOS:官方 `check-macos-release.sh`(只有 x86_64、minos 12.0、只依赖系统库);没有弱导入(不用 12.0 以后的系统接口);没有链入 libsodium;`CKey::MakeNewKey` 和 `randombytes` 都调用 `GetStrongRandBytes`;DMG 校验通过,里面的程序和测过的逐字节一致。
  Official `check-macos-release.sh` (x86_64 only, minos 12.0, system libraries only); no weak imports; no libsodium; `CKey::MakeNewKey` and `randombytes` call `GetStrongRandBytes`; the DMG verifies and holds the exact binaries that were tested.
- Windows:只导入 Windows 系统 DLL;没有 libsodium;`randombytes` 只有一份定义。
  Imports only Windows system DLLs; no libsodium; a single `randombytes` definition.
- 钱包实测 / Wallet test — `scripts/wallet-smoke.sh`,regtest 测试链 / regtest chain;macOS 在 `macos-15-intel` 上跑,Windows 在 `windows-latest` 上跑:
  新建钱包得到 62 位 sq1p 地址 → 备份 → 挖矿到该地址并转出 → 用备份恢复后余额一致、能转出 → 第二个新钱包的地址不同(排除固定种子)。
  new 62-char sq1p address → backup → mine to it and spend → restore from the backup: same balance, can spend → a second new wallet gets a different address (rules out a fixed-seed key generator).
- **没测过 / Not tested**:真机上的 macOS 12–14 及 15 以外的版本、M 芯片 Mac、主网收发。
  real macOS 12–14 or any version other than the macOS 15 runner, Apple-silicon Macs, mainnet sends.

## 下载 / Downloads

Actions → 最近一次成功的 `build-macos` / `build-windows` 运行 → **Artifacts**(需要登录 GitHub;保留 90 天)。
Actions → the latest successful `build-macos` / `build-windows` run → **Artifacts** (GitHub login required; kept for 90 days).

- macOS: `soqucoin-v2.5.2-macos12-x64-wallet.dmg`(和 `.tar.gz`)
- Windows: `soqucoin-v2.5.2-windows-x64-wallet.zip`

每次重新构建哈希都会变,以那次运行页面的 Summary 和 `SHA256SUMS.txt` 为准。2026-10-19 那一版:
Hashes change with every rebuild; trust the run's Summary and `SHA256SUMS.txt`. The 2026-10-19 builds:

| 文件 / File | SHA-256 | 运行 / Run |
|---|---|---|
| `soqucoin-v2.5.2-windows-x64-wallet.zip` | `1cb37e10969737df653d373860d2ac1ac08f2e2d88e53ada2a49a3631cf3e938` | 39291541688 |
| `soqucoin-v2.5.2-macos12-x64-wallet.dmg` | `85fd784ee9b5295e8390d2e0073d9b05c7458304380d91f20e8fdc7105911aaf` | 39296195211 |
| `soqucoin-v2.5.2-macos12-x64-wallet.tar.gz` | `ca4c1dacfc402654f7a474e1ff14d0e873c73489aea7aac470b751af01e71b13` | 39296195211 |

用法见各包里的说明 / Usage: see the notes inside each package —
`packaging/macos/使用说明.txt`(中文)、`packaging/macos/README-macos12.txt`、`packaging/windows/README-windows.txt`。
这个钱包没有助记词,备份只含备份那一刻已有的钥匙:每次生成新地址、每次转出之后都要重新备份。
The wallet has no recovery phrase and a backup only holds the keys that existed when it was made: back up again after every new address and every payment.

## 目录 / Layout

```
.github/workflows/build-macos.yml     macOS 构建 + 检查 + 实测 + DMG / build, checks, test, DMG
.github/workflows/build-windows.yml   Windows 交叉编译 + 检查,再到 Windows 上实测 / cross-build, checks, test on Windows
scripts/macos-build.sh                macOS:从源码编依赖库和 SOQ / build libraries and SOQ from source
scripts/macos-verify.sh               macOS:二进制检查 / binary checks
scripts/wallet-smoke.sh               两个平台共用的钱包实测 / wallet test, both platforms
packaging/macos/                      DMG 里的说明和安装脚本 / notes + installer for the DMG
packaging/windows/                    Windows 包里的说明 / notes for the Windows zip
```
