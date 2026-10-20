# soqucoin-wallet-build

Builds **Soqucoin Core v2.5.2 with the wallet** from the official source, for **Intel Macs (macOS 12+, DMG)**, **Apple Silicon Macs (macOS 11+, DMG)** and **Windows x64**.

Why: the official v2.5.2 macOS packages are built without the wallet and need macOS 15; the official Windows package has the wallet, but the official pipeline never runs it on Windows.

Command-line programs only (`soqucoind` + `soqucoin-cli`), no GUI; the binaries are not signed with a developer ID (the Apple Silicon ones carry only the ad-hoc signature the linker adds).

## How it is built

- Source: [soqucoin/soqucoin](https://github.com/soqucoin/soqucoin) tag `v2.5.2`, commit `35b38fce` — checked on every run.
- **macOS, Intel** — `.github/workflows/build-macos.yml`, GitHub `macos-15-intel`, Xcode 16.4:
  OpenSSL 3.6.3, Boost 1.92.0, libevent 2.1.13 and Berkeley DB 5.3.28 are all built from source (source archives pinned by SHA-256) for macOS 12.0, x86_64, statically linked; wallet on, ZMQ / UPnP / GUI off.
- **macOS, Apple Silicon** — `.github/workflows/build-macos-arm64.yml`, GitHub `macos-15` (arm64), Xcode 16.4:
  the same script and libraries, built natively for arm64 and macOS 11.0 (the first macOS for Apple Silicon); the binaries carry the linker's ad-hoc signature, which Apple Silicon requires.
- **Windows** — `.github/workflows/build-windows.yml`, cross-compiled on `ubuntu-22.04`:
  same recipe as the official release (`depends/`, mingw-w64 POSIX threads) plus `--disable-shared`, so the .exe files need no extra DLLs.

## Checks and tests

- macOS: the official `check-macos-release.sh` (one architecture only, the expected minos, system libraries only); no weak imports (no system APIs newer than the deployment target); no libsodium linked in; `CKey::MakeNewKey` and `randombytes` both call `GetStrongRandBytes`; the DMG verifies and holds byte-identical copies of the binaries that were tested. Apple Silicon also: `codesign --verify --strict` passes, before and after the DMG install test.
- Windows: imports only Windows system DLLs; no libsodium; a single `randombytes` definition.
- Wallet test — `scripts/wallet-smoke.sh` on a regtest chain; Intel macOS runs it on `macos-15-intel`, Apple Silicon on `macos-15` (arm64), Windows on `windows-latest`:
  a new wallet gives a 62-character sq1p address → backup → mine to it and spend → restore from the backup: same balance, can spend → a second new wallet gets a different address (rules out a fixed-seed key generator).
- **Not tested**: real Macs (only GitHub's macOS 15 runners), any macOS older than 15 (Intel 12–14, Apple Silicon 11–14), mainnet sends.

## Downloads

Actions → the latest successful `build-macos` / `build-macos-arm64` / `build-windows` run → **Artifacts** (GitHub login required; kept for 90 days).

- Intel Mac: `soqucoin-v2.5.2-macos12-x64-wallet.dmg` (and `.tar.gz`)
- Apple Silicon Mac: `soqucoin-v2.5.2-macos11-arm64-wallet.dmg` (and `.tar.gz`)
- Windows: `soqucoin-v2.5.2-windows-x64-wallet.zip`

Hashes change with every rebuild; trust the run's Summary and `SHA256SUMS.txt`. The builds of 2026-10-19:

| File | SHA-256 | Run |
|---|---|---|
| `soqucoin-v2.5.2-windows-x64-wallet.zip` | `1cb37e10969737df653d373860d2ac1ac08f2e2d88e53ada2a49a3631cf3e938` | 39291541688 |
| `soqucoin-v2.5.2-macos12-x64-wallet.dmg` | `85fd784ee9b5295e8390d2e0073d9b05c7458304380d91f20e8fdc7105911aaf` | 39296195211 |
| `soqucoin-v2.5.2-macos12-x64-wallet.tar.gz` | `ca4c1dacfc402654f7a474e1ff14d0e873c73489aea7aac470b751af01e71b13` | 39296195211 |

Usage: see the notes inside each package — `packaging/macos/README-macos12.txt`, `packaging/macos-arm64/README-macos11-arm64.txt` and `packaging/windows/README-windows.txt`.
The wallet has no recovery phrase and a backup only holds the keys that existed when it was made: back up again after every new address and every payment.

## Layout

```
.github/workflows/build-macos.yml     Intel macOS build, checks, wallet test, DMG
.github/workflows/build-macos-arm64.yml  Apple Silicon macOS build, checks, wallet test, DMG
.github/workflows/build-windows.yml   Windows cross-build and checks, then wallet test on Windows
scripts/macos-build.sh                macOS: build the libraries and Soqucoin from source (ARCH=x86_64 or arm64)
scripts/macos-verify.sh               macOS: binary checks (ARCH=x86_64 or arm64)
scripts/wallet-smoke.sh               wallet test, both platforms
packaging/macos/                      Intel notes, and the installer used by both DMGs
packaging/macos-arm64/                Apple Silicon notes
packaging/windows/                    notes that go into the Windows zip
```

## Notes

- English is the default language of this repository. Other languages are added in the Notes section at the end of each document: here, and at the end of the package notes (both macOS notes have Chinese there).

<details>
<summary>中文说明</summary>

用官方源码编译带钱包的 Soqucoin Core v2.5.2:Intel Mac(macOS 12 及以上,DMG)、Apple 芯片 Mac(macOS 11 及以上,DMG)和 Windows x64。

- 为什么要自己编:官方 v2.5.2 的 macOS 包编译时关掉了钱包,而且要 macOS 15;官方 Windows 包带钱包,但官方流程没有在 Windows 上实际运行过。
- 只有命令行程序(`soqucoind` + `soqucoin-cli`),没有图形界面;产物没有开发者签名(Apple 芯片版只有链接器加的临时签名)。
- 怎么编的:源码是官方 tag `v2.5.2`(commit `35b38fce`,每次构建都核对)。Intel Mac 版在 GitHub `macos-15-intel` 上从源码编 OpenSSL、Boost、libevent、Berkeley DB(源码包 SHA-256 固定),目标 macOS 12.0、x86_64、静态链接;Apple 芯片版用同一套脚本在 GitHub `macos-15`(arm64)上原生编,目标 macOS 11.0,程序带链接器的临时签名(Apple 芯片要求有签名才能运行);Windows 在 `ubuntu-22.04` 上照官方配方交叉编译,另加 `--disable-shared`,不依赖额外 DLL。
- 检查与实测:macOS 跑官方 `check-macos-release.sh`、查弱导入和 libsodium、核对随机数来源,DMG 里的程序和测过的逐字节一致,Apple 芯片版另外核签名;Windows 只导入系统 DLL。三个版本都在各自平台的 regtest 测试链上实测钱包:新建地址 → 备份 → 挖矿并转出 → 用备份恢复后余额一致、能转出 → 第二个新钱包地址不同。
- 没测过:真机(只在 GitHub 的 macOS 15 机器上跑过)、比 15 老的 macOS(Intel 12–14、Apple 芯片 11–14)、主网收发。
- 下载:Actions → 最近一次成功的 `build-macos` / `build-macos-arm64` / `build-windows` → Artifacts(要登录 GitHub,保留 90 天)。每次重新构建哈希都会变,以那次运行的 Summary 和 `SHA256SUMS.txt` 为准;2026-10-19 那一版的哈希见上面的表。
- 用法:macOS 的中文说明在说明文件文末的 Notes 里(Intel 版 `packaging/macos/README-macos12.txt`,Apple 芯片版 `packaging/macos-arm64/README-macos11-arm64.txt`,DMG 和 .tar.gz 里是同一个文件);Windows 只有英文说明 `packaging/windows/README-windows.txt`。
- 这个钱包没有助记词,备份只含备份那一刻已有的钥匙:每次生成新地址、每次转出之后都要重新备份。

</details>
