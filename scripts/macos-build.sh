#!/usr/bin/env bash
# Build soqucoind + soqucoin-cli WITH the wallet for Intel Macs running macOS 12 (Monterey) or later.
#
# Why this exists: the official v2.5.2 macOS packages are built with --disable-wallet and for macOS 15.0
# (Homebrew bottles), so they cannot generate addresses and do not start on macOS 12.
#
# What it does:
#   - takes the official source at tag v2.5.2 (commit pinned, checked);
#   - builds every library from source with MACOSX_DEPLOYMENT_TARGET=12.0, static, x86_64 only:
#     OpenSSL 3.6.3, Boost 1.92.0 (the versions the official v2.5.2 macOS build used), libevent 2.1.13-stable,
#     Berkeley DB 5.3.28 (the version SOQ's own depends/ uses, with its patches) — every tarball is checked
#     against a pinned SHA-256;
#   - configures SOQ with the wallet on, and ZMQ / UPnP / GUI / tests / bench off (the wallet needs none of them;
#     leaving ZMQ out also keeps libsodium out, whose own randombytes() would otherwise compete with the node's);
#   - fails if any archive was built for a newer macOS than 12.0.
# Usage: scripts/macos-build.sh <soqucoin source dir> <work dir>
set -euo pipefail

SRC=$(cd "$1" && pwd)
WORK=$(mkdir -p "$2" && cd "$2" && pwd)
PREFIX=$WORK/deps
DL=$WORK/dl
BLD=$WORK/build
mkdir -p "$PREFIX" "$DL" "$BLD"

: "${MACOSX_DEPLOYMENT_TARGET:=12.0}"
export MACOSX_DEPLOYMENT_TARGET
ARCH=x86_64
JOBS=$(sysctl -n hw.ncpu)
SDK=$(xcrun --sdk macosx --show-sdk-path)
export CC="$(xcrun -f clang)" CXX="$(xcrun -f clang++)"
# The toolchain clang (not the /usr/bin/clang shim) only finds the SDK through SDKROOT or -isysroot, and autoconf's
# preprocessor-only probes (header "presence", "ANSI C header files") use CPPFLAGS, not CFLAGS. Run 1 failed exactly
# there: BDB's configure saw no system headers and fell back to <varargs.h>. So: SDKROOT + -isysroot in CPPFLAGS too.
export SDKROOT="$SDK"
COMMON="-arch $ARCH -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET -isysroot $SDK"
export CPPFLAGS="-isysroot $SDK -mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET"
export CFLAGS="$COMMON -O2"
export CXXFLAGS="$COMMON -O2 -stdlib=libc++"
export LDFLAGS="$COMMON"
# Only our prefix: never pick up Homebrew's openssl / boost / bdb / libevent / zeromq.
export PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig"

fetch() {  # url file sha256
  local url=$1 file=$2 sum=$3
  [ -f "$DL/$file" ] || curl -fL --retry 5 --retry-delay 5 -o "$DL/$file" "$url"
  echo "$sum  $DL/$file" | shasum -a 256 -c -
}

echo "::group::sources"
fetch "https://github.com/openssl/openssl/releases/download/openssl-3.6.3/openssl-3.6.3.tar.gz" \
      openssl-3.6.3.tar.gz 243a86649cf6f23eeb6a2ff2456e09e5d77dd9018a54d3d96b0c6bdd6ba6c7f1
fetch "https://archives.boost.io/release/1.92.0/source/boost_1_92_0.tar.bz2" \
      boost_1_92_0.tar.bz2 5c1d40cb8e19adbf740a4ec2da35b3e58f3f5804b1dce44deb53df72193cbc6c
fetch "https://github.com/libevent/libevent/releases/download/release-2.1.13-stable/libevent-2.1.13-stable.tar.gz" \
      libevent-2.1.13-stable.tar.gz f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c
fetch "https://download.oracle.com/berkeley-db/db-5.3.28.NC.tar.gz" \
      db-5.3.28.NC.tar.gz 76a25560d9e52a198d37a31440fd07632b5f1f8f9f2b6d5438f4bc3e7c9013ef
echo "::endgroup::"

echo "::group::openssl"
cd "$BLD" && rm -rf openssl-3.6.3 && tar xzf "$DL/openssl-3.6.3.tar.gz" && cd openssl-3.6.3
./Configure darwin64-x86_64-cc no-shared no-tests no-docs --prefix="$PREFIX" --libdir=lib \
  "-mmacosx-version-min=$MACOSX_DEPLOYMENT_TARGET" -isysroot "$SDK"
make -j"$JOBS" build_libs >"$WORK/openssl.log" 2>&1 || { tail -50 "$WORK/openssl.log"; exit 1; }
make install_dev >>"$WORK/openssl.log" 2>&1
echo "::endgroup::"

echo "::group::boost"
cd "$BLD" && rm -rf boost_1_92_0 && tar xjf "$DL/boost_1_92_0.tar.bz2" && cd boost_1_92_0
./bootstrap.sh --with-toolset=clang --with-libraries=chrono,filesystem,program_options,thread >"$WORK/boost.log" 2>&1 \
  || { tail -50 "$WORK/boost.log"; exit 1; }
./b2 -j"$JOBS" -d1 toolset=clang architecture=x86 address-model=64 variant=release link=static threading=multi \
  runtime-link=shared cxxflags="$CXXFLAGS" cflags="$CFLAGS" linkflags="$LDFLAGS" \
  --prefix="$PREFIX" --layout=system install >>"$WORK/boost.log" 2>&1 || { tail -80 "$WORK/boost.log"; exit 1; }
echo "::endgroup::"

echo "::group::libevent"
cd "$BLD" && rm -rf libevent-2.1.13-stable && tar xzf "$DL/libevent-2.1.13-stable.tar.gz" && cd libevent-2.1.13-stable
./configure --prefix="$PREFIX" --disable-shared --enable-static --disable-openssl --disable-libevent-regress \
  --disable-samples --disable-debug-mode >"$WORK/libevent.log" 2>&1 || { tail -50 "$WORK/libevent.log"; exit 1; }
grep -q "^checking for sys/select.h... yes" "$WORK/libevent.log" || { echo "libevent configure: sys/select.h not detected" >&2; grep -E "^checking for sys/" "$WORK/libevent.log" >&2; exit 1; }
make -j"$JOBS" >>"$WORK/libevent.log" 2>&1 && make install >>"$WORK/libevent.log" 2>&1
echo "::endgroup::"

echo "::group::bdb"
cd "$BLD" && rm -rf db-5.3.28.NC && tar xzf "$DL/db-5.3.28.NC.tar.gz" && cd db-5.3.28.NC
# Same renames as soqucoin depends/packages/bdb.mk (clang's own __atomic_compare_exchange / atomic_init clash).
sed -i.old 's/__atomic_compare_exchange/__atomic_compare_exchange_db/' src/dbinc/atomic.h
sed -i.old 's/atomic_init/atomic_init_db/' src/dbinc/atomic.h src/mp/mp_region.c src/mp/mp_mvcc.c src/mp/mp_fget.c \
  src/mutex/mut_method.c src/mutex/mut_tas.c
cd build_unix
# Modern clang turns old-style C (implicit declarations / int conversions) in BDB's configure probes and sources into
# errors, which makes configure mis-detect features (e.g. no mutex implementation). Keep them warnings.
BDB_CWARN="-Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-function-pointer-types"
CFLAGS="$CFLAGS $BDB_CWARN" CXXFLAGS="$CXXFLAGS -std=c++11" \
  ../dist/configure --prefix="$PREFIX" --disable-shared --enable-static --enable-cxx --disable-replication \
  >"$WORK/bdb.log" 2>&1 || { tail -60 "$WORK/bdb.log"; exit 1; }
grep -E "^checking for mutexes" "$WORK/bdb.log" || true
# Fail early if configure mis-detected the basics again (it would build against <varargs.h> or without pthreads).
grep -q "^checking for ANSI C header files... yes" "$WORK/bdb.log" || { echo "BDB configure: ANSI C headers not detected" >&2; grep -E "^checking" "$WORK/bdb.log" | grep -E "presence\.\.\. no|header files" >&2; exit 1; }
grep -q "^checking pthread.h presence... yes" "$WORK/bdb.log" || { echo "BDB configure: pthread.h not detected" >&2; exit 1; }
make -j"$JOBS" libdb_cxx-5.3.a libdb-5.3.a >>"$WORK/bdb.log" 2>&1 || { tail -60 "$WORK/bdb.log"; exit 1; }
make install_lib install_include >>"$WORK/bdb.log" 2>&1
echo "::endgroup::"

echo "::group::soqucoin configure"
cd "$SRC"
./autogen.sh >"$WORK/autogen.log" 2>&1 || { tail -40 "$WORK/autogen.log"; exit 1; }
# BREW=false: configure.ac asks `brew --prefix openssl` / `berkeley-db@N` when brew is on PATH (the runner has
# Homebrew's openssl@3 preinstalled); false makes those lookups come back empty so only $PREFIX is used.
BREW=false ./configure --without-gui --disable-tests --disable-bench --disable-shared --enable-wallet \
  --disable-zmq --without-miniupnpc \
  --with-boost="$PREFIX" --with-boost-libdir="$PREFIX/lib" \
  BDB_CFLAGS="-I$PREFIX/include" BDB_LIBS="-L$PREFIX/lib -ldb_cxx-5.3 -ldb-5.3" \
  CPPFLAGS="$CPPFLAGS -I$PREFIX/include" LDFLAGS="$LDFLAGS -L$PREFIX/lib" 2>&1 | tee "$WORK/configure.log"
grep -E "with wallet *= *yes" "$WORK/configure.log" || { echo "wallet is not enabled" >&2; exit 1; }
grep -E "with zmq *= *no" "$WORK/configure.log" || { echo "zmq should be off" >&2; exit 1; }
echo "::endgroup::"

echo "::group::soqucoin make"
make -j"$JOBS" >"$WORK/build.log" 2>&1 || { grep -E "error:" "$WORK/build.log" | head -40; tail -80 "$WORK/build.log"; exit 1; }
# Any call to an API newer than the deployment target (clang: "... is only available on macOS 13.0 or newer").
if grep -hnE 'only available on macOS (1[3-9]|2[0-9])|\[-Wunguarded-availability' "$WORK"/*.log; then
  echo "something uses an API newer than macOS $MACOSX_DEPLOYMENT_TARGET" >&2
  exit 1
fi
if grep -m 5 'built for newer' "$WORK/build.log"; then
  echo "an archive needs a newer macOS than $MACOSX_DEPLOYMENT_TARGET" >&2
  exit 1
fi
test -x src/soqucoind && test -x src/soqucoin-cli
echo "::endgroup::"
