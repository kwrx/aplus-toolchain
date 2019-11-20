#!/bin/bash

host=$1
binutils="2.31"
gcc="8.2.0"
autoconf="2.69"
autoconf_gcc="2.64"
automake="1.15.1"


mkdir -p toolchain
mkdir -p tmp
mkdir -p tmp/src



PATCH=$(pwd)/patch
PREFIX=$(pwd)/toolchain
TEMP=$(pwd)/tmp
TARGET=$host-aplus

export PATH="$PREFIX/bin:$TEMP/bin:$PATH"



# Download sources
wget -P tmp/src https://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf.tar.xz                    || exit 1
wget -P tmp/src https://ftp.gnu.org/gnu/autoconf/autoconf-$autoconf_gcc.tar.xz                || exit 1
wget -P tmp/src https://ftp.gnu.org/gnu/automake/automake-$automake.tar.xz                    || exit 1
wget -P tmp/src http://ftp.gnu.org/gnu/binutils/binutils-$binutils.tar.xz                     || exit 1
wget -P tmp/src http://mirror2.mirror.garr.it/mirrors/gnuftp/gcc/gcc-$gcc/gcc-$gcc.tar.xz     || exit 1


# Extract
tar -xJf tmp/src/autoconf-$autoconf.tar.xz -C tmp/src                 || exit 1
tar -xJf tmp/src/autoconf-$autoconf_gcc.tar.xz -C tmp/src             || exit 1
tar -xJf tmp/src/automake-$automake.tar.xz -C tmp/src                 || exit 1
tar -xJf tmp/src/binutils-$binutils.tar.xz -C tmp/src                 || exit 1
tar -xJf tmp/src/gcc-$gcc.tar.xz -C tmp/src                           || exit 1


# Autoconf
pushd tmp/src/autoconf-$autoconf

    mkdir -p build

    pushd build
        ../configure --prefix=$TEMP                 || exit 1
        make -j2                                    || exit 1
        make -j2 install                            || exit 1
    popd

popd

# Automake
pushd tmp/src/automake-$automake

    mkdir -p build
    
    pushd build
        ../configure --prefix=$TEMP                 || exit 1
        make -j2                                    || exit 1
        make -j2 install                            || exit 1
    popd

popd

# Binutils
pushd tmp/src/binutils-$binutils

    mkdir -p build

    # Patch
    patch -p1 < $PATCH/binutils-$binutils.patch             || exit 1

    pushd ld
        automake                                            || exit 1
    popd

    pushd build
        ../configure --prefix=$PREFIX --target=$TARGET      || exit 1
        make -j2                                            || exit 1
        make -j2 install                                    || exit 1
    popd

popd

# Autoconf (GCC)
pushd tmp/src/autoconf-$autoconf_gcc

    mkdir -p build
    
    pushd build
        ../configure --prefix=$TEMP                 || exit 1
        make -j2                                    || exit 1
        make -j2 install                            || exit 1
    popd    

popd

# GCC
pushd tmp/src/gcc-$gcc

    mkdir -p build

    # Patch
    patch -p1 < $PATCH/gcc-$gcc.patch               || exit 1

    pushd libstdc++-v3
        autoconf                                    || exit 1
    popd


    mkdir -p $PREFIX/$TARGET/include

    pushd $PREFIX/$TARGET/include
        patch -p1 < $PATCH/gcc-headers.patch        || exit 1
    popd


    pushd build
        ../configure --prefix=$PREFIX --target=$TARGET --enable-languages=c,c++ --disable-nls   || exit 1
        make -j2 all-gcc                                                                        || exit 1
        make -j2 all-target-libgcc                                                              || exit 1
        make -j2 install-gcc                                                                    || exit 1
        make -j2 install-target-libgcc                                                          || exit 1
    popd

popd


# Strip binaries
pushd $PREFIX/bin
    strip *
popd

pushd $PREFIX/$TARGET/bin
    strip *
popd

pushd $PREFIX/libexec/gcc/$TARGET/$gcc
    strip cc1 cc1plus collect2 lto-wrapper lto1
popd

# Pack Release
pushd toolchain
    rm -rf $PREFIX/$TARGET/include/*
    tar -cJf $TARGET-toolchain-nocxx.tar.xz *
popd

mv toolchain/$TARGET-toolchain-nocxx.tar.xz .



# Install newlib
wget -P tmp/src https://github.com/kwrx/aplus-newlib/releases/latest/download/$TARGET-newlib.tar.xz || exit 1
tar -xJf tmp/src/$TARGET-newlib.tar.xz -C $PREFIX                                                   || exit 1

# Libstdc++-v3
pushd tmp/src/gcc-$gcc
    pushd build
        make -j2 all-target-libstdc++-v3                                                            || exit 1
        make -j2 install-target-libstdc++-v3                                                        || exit 1
    popd
popd

# Pack Release
pushd toolchain
    tar -cJf $TARGET-toolchain.tar.xz *
popd

mv toolchain/$TARGET-toolchain.tar.xz .



# Clean
rm -rf $TEMP