# soqucoin-wallet-build

Builds **Soqucoin Core v2.5.2 with the wallet** from the official source, for **Intel Macs (macOS 12+, DMG)** and **Windows x64**.

Why: the official v2.5.2 macOS packages are built without the wallet and need macOS 15; the official Windows package has the wallet, but the official pipeline never runs it on Windows.

Command-line programs only (`soqucoind` + `soqucoin-cli`), no GUI; the binaries are not signed.

## How it is built

- Source: [soqucoin/soqucoin](https://github.com/soqucoin/soqucoin) tag `v2.5.2`, commit `35b38fce` — checked on every run.
- **macOS** — `.github/workflows/build-macos.yml`, GitHub `macos-15-intel`, Xcode 16.4:
  OpenSSL 3.6.3, Boost 1.92.0, libevent 2.1.13 and Berkeley DB 5.3.28 are all built from source (source archives pinned by SHA-256) for macOS 12.0, x86_64, statically linked; wallet on, ZMQ / UPnP / GUI off.
- **Windows** — `.github/workflows/build-windows.yml`, cross-compiled on `ubuntu-22.04`:
  same recipe as the official release (`depends/`, mingw-w64 POSIX threads) plus `--disable-shared`, so the .exe files need no extra DLLs.

## Checks and tests

- macOS: the official `check-macos-release.sh` (x86_64 only, minos 12.0, system libraries only); no weak imports (no system APIs newer than 12.0); no libsodium linked in; `CKey::MakeNewKey` and `randombytes` both call `GetStrongRandBytes`; the DMG verifies and holds byte-identical copies of the binaries that were tested.
- Windows: imports only Windows system DLLs; no libsodium; a single `randombytes` definition.
- Wallet test — `scripts/wallet-smoke.sh` on a regtest chain; macOS runs it on `macos-15-intel`, Windows on `windows-latest`:
  a new wallet gives a 62-character sq1p address → backup → mine to it and spend → restore from the backup: same balance, can spend → a second new wallet gets a different address (rules out a fixed-seed key generator).
- **Not tested**: real machines running macOS 12–14 or any macOS other than the macOS 15 runner, Apple-silicon Macs, mainnet sends.

## Downloads

Actions → the latest successful `build-macos` / `build-windows` run → **Artifacts** (GitHub login required; kept for 90 days).

- macOS: `soqucoin-v2.5.2-macos12-x64-wallet.dmg` (and `.tar.gz`)
- Windows: `soqucoin-v2.5.2-windows-x64-wallet.zip`

Hashes change with every rebuild; trust the run's Summary and `SHA256SUMS.txt`. The builds of 2026-10-19:

| File | SHA-256 | Run |
|---|---|---|
| `soqucoin-v2.5.2-windows-x64-wallet.zip` | `1cb37e10969737df653d373860d2ac1ac08f2e2d88e53ada2a49a3631cf3e938` | 39291541688 |
| `soqucoin-v2.5.2-macos12-x64-wallet.dmg` | `85fd784ee9b5295e8390d2e0073d9b05c7458304380d91f20e8fdc7105911aaf` | 39296195211 |
| `soqucoin-v2.5.2-macos12-x64-wallet.tar.gz` | `ca4c1dacfc402654f7a474e1ff14d0e873c73489aea7aac470b751af01e71b13` | 39296195211 |

Usage: see the notes inside each package — `packaging/macos/README-macos12.txt` and `packaging/windows/README-windows.txt`.
The wallet has no recovery phrase and a backup only holds the keys that existed when it was made: back up again after every new address and every payment.

## Layout

```
.github/workflows/build-macos.yml     macOS build, checks, wallet test, DMG
.github/workflows/build-windows.yml   Windows cross-build and checks, then wallet test on Windows
scripts/macos-build.sh                macOS: build the libraries and Soqucoin from source
scripts/macos-verify.sh               macOS: binary checks
scripts/wallet-smoke.sh               wallet test, both platforms
packaging/macos/                      notes and installer that go into the DMG
packaging/windows/                    notes that go into the Windows zip
```

## Notes

- English is the default language of this repository. Other languages are added in the Notes section at the end of each document: here, and at the end of the package notes (`packaging/macos/README-macos12.txt` has Chinese there).

<details>
<summary>中文说明</summary>

用官方源码编译带钱包的 Soqucoin Core v2.5.2:Intel Mac(macOS 12 及以上,DMG)和 Windows x64。

- 为什么要自己编:官方 v2.5.2 的 macOS 包编译时关掉了钱包,而且要 macOS 15;官方 Windows 包带钱包,但官方流程没有在 Windows 上实际运行过。
- 只有命令行程序(`soqucoind` + `soqucoin-cli`),没有图形界面;产物没有签名。
- 怎么编的:源码是官方 tag `v2.5.2`(commit `35b38fce`,每次构建都核对)。macOS 在 GitHub `macos-15-intel` 上从源码编 OpenSSL、Boost、libevent、Berkeley DB(源码包 SHA-256 固定),目标 macOS 12.0、x86_64、静态链接;Windows 在 `ubuntu-22.04` 上照官方配方交叉编译,另加 `--disable-shared`,不依赖额外 DLL。
- 检查与实测:macOS 跑官方 `check-macos-release.sh`、查弱导入和 libsodium、核对随机数来源,DMG 里的程序和测过的逐字节一致;Windows 只导入系统 DLL。两个平台都在 regtest 测试链上实测钱包:新建地址 → 备份 → 挖矿并转出 → 用备份恢复后余额一致、能转出 → 第二个新钱包地址不同。
- 没测过:真机上的 macOS 12–14 及 15 以外的版本、M 芯片 Mac、主网收发。
- 下载:Actions → 最近一次成功的 `build-macos` / `build-windows` → Artifacts(要登录 GitHub,保留 90 天)。每次重新构建哈希都会变,以那次运行的 Summary 和 `SHA256SUMS.txt` 为准;2026-10-19 那一版的哈希见上面的表。
- 用法:macOS 的中文说明在 `packaging/macos/README-macos12.txt` 文末的 Notes 里(DMG 和 .tar.gz 里是同一个文件);Windows 只有英文说明 `packaging/windows/README-windows.txt`。
- 这个钱包没有助记词,备份只含备份那一刻已有的钥匙:每次生成新地址、每次转出之后都要重新备份。

</details>
