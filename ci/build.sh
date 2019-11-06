#!/bin/bash

host=$1
binutils="2.31"
gcc="8.2.0"
autoconf="2.69"
autoconf_gcc="2.64"
automake="1.15.1"


mkdir -p toolchain
mkdir -p toolchain/src
mkdir -p toolchain/tmp



PATCH=$(pwd)/patch
PREFIX=$(pwd)/toolchain
TARGET=$host-aplus

export PATH="$PREFIX/bin:$PREFIX/tmp/bin:$PATH"



# Download sources
wget -P toolchain/src https://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf.tar.xz                    || exit 1
wget -P toolchain/src https://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf_gcc.tar.xz                || exit 1
wget -P toolchain/src https://ftp.gnu.org/gnu/automake/automake-$automake.tar.xz                    || exit 1
wget -P toolchain/src http://ftp.gnu.org/gnu/binutils/binutils-$binutils.tar.xz                     || exit 1
wget -P toolchain/src http://mirror2.mirror.garr.it/mirrors/gnuftp/gcc/gcc-$gcc/gcc-$gcc.tar.xz     || exit 1


# Extract
tar -xJf toolchain/src/autoconf-$autoconf.tar.xz -C toolchain/src                 || exit 1
tar -xJf toolchain/src/autoconf-$autoconf_gcc.tar.xz -C toolchain/src             || exit 1
tar -xJf toolchain/src/automake-$automake.tar.xz -C toolchain/src                 || exit 1
tar -xJf toolchain/src/binutils-$binutils.tar.xz -C toolchain/src                 || exit 1
tar -xJf toolchain/src/gcc-$gcc.tar.xz -C toolchain/src                           || exit 1


# Autoconf
pushd toolchain/src/autoconf-$autoconf

    mkdir -p build

    pushd build
        ../configure --prefix=$PREFIX/tmp           || exit 1
        make                                        || exit 1
        make install                                || exit 1
    popd

popd

# Automake
pushd toolchain/src/automake-$automake

    mkdir -p build
    
    pushd build
        ../configure --prefix=$PREFIX/tmp           || exit 1
        make                                        || exit 1
        make install                                || exit 1
    popd

popd

# Binutils
pushd toolchain/src/binutils-$binutils

    mkdir -p build

    # Patch
    patch -p1 < $PATCH/binutils-$binutils.patch             || exit 1

    pushd ld
        automake                                            || exit 1
    popd

    pushd build
        ../configure --prefix=$PREFIX --target=$TARGET      || exit 1
        make                                                || exit 1
        make install                                        || exit 1
    popd

popd

# Autoconf (GCC)
pushd toolchain/src/autoconf-$autoconf_gcc

    mkdir -p build
    
    pushd build
        ../configure --prefix=$PREFIX/tmp           || exit 1
        make                                        || exit 1
        make install                                || exit 1
    popd    

popd

# GCC
pushd toolchain/src/gcc

    mkdir -p build

    # Patch
    patch -p1 < $PATCH/gcc-$gcc.patch               || exit 1

    pushd libstdc++-v3
        autoconf                                    || exit 1
    popd

    pushd $PREFIX/$TARGET/include
        patch -p1 < $PATCH/gcc-headers.patch        || exit 1
    popd

    
    # Dependencies (mpfr, mpc, isl)
    ./contrib/download_prerequisites                || exit 1


    pushd build
        ../configure --prefix=$PREFIX --target=$TARGET --enable-languages=c,c++ --disable-nls   || exit 1
        make all-gcc                                                                            || exit 1
        make all-target-libgcc                                                                  || exit 1
        make install-gcc                                                                        || exit 1
        make install-target-libgcc                                                              || exit 1
    popd

popd


pushd $PREFIX/bin
    strip *
popd

pushd $PREFIX/$TARGET/bin
    strip *
popd

pushd $PREFIX/libexec/gcc/$TARGET/$gcc
    strip cc1 cc1plus collect2 lto-wrapper lto1
popd

pushd toolchain
    rm -rf tmp
    rm -rf src
    rm -rf $PREFIX/$TARGET/include/*
    tar -cJf $TARGET-toolchain-nocxx.tar.xz *
popd