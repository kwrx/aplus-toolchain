#!/bin/bash

binutils="2.31"
gcc="12.2.0"
autoconf="2.69"
autoconf_gcc="2.69"
automake="1.15.1"

function required {
    echo -n "Checking for $1..."
    command -v $1 >/dev/null 2>&1 || {
        echo "$1 is required but it's not installed. Aborting." >&2
        exit 1
    }
    echo $(command -v $1)
}

function die() {
    echo "Running: $@"
    $@ || exit 1
}


# Check arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <target> <host>"
    exit 1
fi

# Set variables
TARGET=$1
HOST=$2
PATCH=$(pwd)/patch
PREFIX=$(pwd)/toolchain
TEMP=$(pwd)/tmp

# Check required tools
required wget
required tar
required patch
required automake
required autoconf
required make
required gcc
required g++
required strip
required nproc
required $HOST-gcc
required $HOST-g++
required $HOST-strip

# Create directories
mkdir -p toolchain
mkdir -p tmp
mkdir -p tmp/src

# Download sources
die wget -q -P tmp/src https://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf.tar.xz
die wget -q -P tmp/src https://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf_gcc.tar.xz
die wget -q -P tmp/src https://ftp.gnu.org/gnu/automake/automake-$automake.tar.xz
die wget -q -P tmp/src http://ftp.gnu.org/gnu/binutils/binutils-$binutils.tar.xz
die wget -q -P tmp/src https://ftp.gnu.org/gnu/gcc/gcc-$gcc/gcc-$gcc.tar.xz

# Extract
die tar -xJf tmp/src/autoconf-$autoconf.tar.xz -C tmp/src
die tar -xJf tmp/src/autoconf-$autoconf_gcc.tar.xz -C tmp/src
die tar -xJf tmp/src/automake-$automake.tar.xz -C tmp/src
die tar -xJf tmp/src/binutils-$binutils.tar.xz -C tmp/src
die tar -xJf tmp/src/gcc-$gcc.tar.xz -C tmp/src

# Set paths
export PATH="$PREFIX/bin:$TEMP/bin:$PATH"


# Autoconf
pushd tmp/src/autoconf-$autoconf

    mkdir -p build

    pushd build
        die ../configure --prefix=$TEMP
        die make -j$(nproc)
        die make -j$(nproc) install
    popd

popd

# Automake
pushd tmp/src/automake-$automake

    mkdir -p build

    pushd build
        die ../configure --prefix=$TEMP
        die make -j$(nproc)
        die make -j$(nproc) install
    popd

popd

# Binutils
pushd tmp/src/binutils-$binutils

    mkdir -p build

    # Patch
    die patch -p1 <$PATCH/binutils-$binutils.patch

    pushd ld
        die automake
    popd

    pushd build
        die ../configure --prefix=$PREFIX --target=$TARGET --host=$HOST \
            --enable-lto                                                \
            --enable-threads=posix                                      \
            --enable-host-shared                                        \
            --disable-shared                                            \
            --disable-nls
        die make -j$(nproc)
        die make -j$(nproc) install
    popd

popd

# Autoconf (GCC)
pushd tmp/src/autoconf-$autoconf_gcc

    mkdir -p build

    pushd build
        ../configure --prefix=$TEMP || exit 1
        make -j$(nproc) || exit 1
        make -j$(nproc) install || exit 1
    popd

popd

# GCC
pushd tmp/src/gcc-$gcc

    mkdir -p build

    # Prerequisites
    die wget -q https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.18.tar.bz2
    die wget -q https://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
    die wget -q https://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.6.tar.bz2
    die wget -q https://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz

    # Extract
    die tar -xf isl-0.18.tar.bz2
    die tar -xf gmp-6.1.0.tar.bz2
    die tar -xf mpfr-3.1.6.tar.bz2
    die tar -xf mpc-1.0.3.tar.gz

    # Rename
    die mv isl-0.18 isl
    die mv gmp-6.1.0 gmp
    die mv mpfr-3.1.6 mpfr
    die mv mpc-1.0.3 mpc

    # Patch
    die patch -p1 <$PATCH/gcc-$gcc.patch

    pushd libstdc++-v3
        die autoconf
    popd

    mkdir -p $PREFIX/$TARGET/include

    pushd $PREFIX/$TARGET/include
        die patch -p1 <$PATCH/gcc-headers.patch
    popd

    pushd build
        die ../configure --prefix=$PREFIX --target=$TARGET --host=$HOST \
            --enable-languages=c,c++                                    \
            --enable-threads=posix                                      \
            --enable-lto                                                \
            --enable-host-shared                                        \
            --disable-shared                                            \
            --disable-nls
        die make -j$(nproc) all-gcc
        die make -j$(nproc) install-gcc
    popd

popd

# C Library
die wget -P tmp/src https://github.com/kwrx/aplus-musl/releases/latest/download/$TARGET-musl.tar.xz
die tar -xJf tmp/src/$TARGET-musl.tar.xz -C $PREFIX

# Libgcc
pushd tmp/src/gcc-$gcc
    pushd build
        die make -j$(nproc) all-target-libgcc
        die make -j$(nproc) install-target-libgcc
    popd
popd

# Strip binaries
pushd $PREFIX/bin
    die $HOST-strip *
popd

pushd $PREFIX/$TARGET/bin
    die $HOST-strip *
popd

pushd $PREFIX/libexec/gcc/$TARGET/$gcc
    die $HOST-strip cc1 cc1plus collect2 lto-wrapper lto1
popd

# Pack Release
pushd toolchain
    die tar -cJf $TARGET-toolchain-nocxx-$HOST.tar.xz *
popd

mv toolchain/$TARGET-toolchain-nocxx-$HOST.tar.xz .

# Libstdc++-v3
pushd tmp/src/gcc-$gcc
    pushd build
        die make -j$(nproc) all-target-libstdc++-v3
        die make -j$(nproc) install-target-libstdc++-v3
    popd
popd

# Pack Release
pushd toolchain
    die tar -cJf $TARGET-toolchain-$HOST.tar.xz *
popd

mv toolchain/$TARGET-toolchain-$HOST.tar.xz .

# Clean
rm -rf $TEMP
