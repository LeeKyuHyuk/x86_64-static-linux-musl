# x86_64-static-linux-musl

A toolchain designed for easy static build! 🛠️

## Preparing Build Environment

Ubuntu 20.04 is recommended.

```bash
sudo apt update
sudo apt install gcc g++ make wget
```

## Step 1) Download All The Packages

```bash
make download
```

## Step 2) Build Toolchain

```bash
make toolchain
```

```
$ out/tools/bin/x86_64-static-linux-musl-gcc --version
x86_64-static-linux-musl-gcc (x86_64 2021.09) 11.2.0
Copyright (C) 2021 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```

## Usage Example

For example, let's build `heif-convert` of `libheif` statically.

Add the build process to `scripts/toolchain.sh` as shown below.

```bash
step "[Build] 1 - libjpeg 9d"
extract $SOURCES_DIR/jpegsrc.v9d.tar.gz $BUILD_DIR
( cd $BUILD_DIR/jpeg-9d && \
    CC="$TOOLS_DIR/bin/$CONFIG_TARGET-gcc" \
    CXX="$TOOLS_DIR/bin/$CONFIG_TARGET-g++" \
    AR="$TOOLS_DIR/bin/$CONFIG_TARGET-ar" \
    AS="$TOOLS_DIR/bin/$CONFIG_TARGET-as" \
    LD="$TOOLS_DIR/bin/$CONFIG_TARGET-ld" \
    RANLIB="$TOOLS_DIR/bin/$CONFIG_TARGET-ranlib" \
    READELF="$TOOLS_DIR/bin/$CONFIG_TARGET-readelf" \
    STRIP="$TOOLS_DIR/bin/$CONFIG_TARGET-strip" \
    ./configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
    --prefix=/usr \
    --enable-static \
    --disable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/jpeg-9d
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/jpeg-9d
rm -rf $BUILD_DIR/jpeg-9d

step "[Build] 2 - libde265 1.0.8"
extract $SOURCES_DIR/libde265-1.0.8.tar.gz $BUILD_DIR
( cd $BUILD_DIR/libde265-1.0.8 && sh autogen.sh )
( cd $BUILD_DIR/libde265-1.0.8 && \
    CC="$TOOLS_DIR/bin/$CONFIG_TARGET-gcc" \
    CXX="$TOOLS_DIR/bin/$CONFIG_TARGET-g++" \
    AR="$TOOLS_DIR/bin/$CONFIG_TARGET-ar" \
    AS="$TOOLS_DIR/bin/$CONFIG_TARGET-as" \
    LD="$TOOLS_DIR/bin/$CONFIG_TARGET-ld" \
    RANLIB="$TOOLS_DIR/bin/$CONFIG_TARGET-ranlib" \
    READELF="$TOOLS_DIR/bin/$CONFIG_TARGET-readelf" \
    STRIP="$TOOLS_DIR/bin/$CONFIG_TARGET-strip" \
    ./configure \
    --target=$CONFIG_TARGET \
    --host=$CONFIG_TARGET \
    --build=$CONFIG_HOST \
    --prefix=/usr \
    --enable-static \
    --disable-shared \
    --disable-encoder \
    --enable-log-error \
    --disable-dec265 \
    --disable-sherlock265 )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libde265-1.0.8
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/libde265-1.0.8
rm -rf $BUILD_DIR/libde265-1.0.8

step "[Build] 3 - libheif 1.12.0"
extract $SOURCES_DIR/libheif-1.12.0.tar.gz $BUILD_DIR
( cd $BUILD_DIR/libheif-1.12.0 && \
    CC="$TOOLS_DIR/bin/$CONFIG_TARGET-gcc" \
    CXX="$TOOLS_DIR/bin/$CONFIG_TARGET-g++" \
    AR="$TOOLS_DIR/bin/$CONFIG_TARGET-ar" \
    AS="$TOOLS_DIR/bin/$CONFIG_TARGET-as" \
    LD="$TOOLS_DIR/bin/$CONFIG_TARGET-ld" \
    RANLIB="$TOOLS_DIR/bin/$CONFIG_TARGET-ranlib" \
    READELF="$TOOLS_DIR/bin/$CONFIG_TARGET-readelf" \
    STRIP="$TOOLS_DIR/bin/$CONFIG_TARGET-strip" \
    LDFLAGS="-static-libstdc++ -static-libgcc -static" \
    cmake \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DENABLE_SHARED=OFF \
    -DLIBDE265_INCLUDE_DIR=$SYSROOT_DIR/include/libde265 \
    -DLIBDE265_LIBRARY=$SYSROOT_DIR/lib/libde265.a \
    -DJPEG_LIBRARY_RELEASE=$SYSROOT_DIR/lib/libjpeg.a )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libheif-1.12.0
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/libheif-1.12.0
rm -rf $BUILD_DIR/libheif-1.12.0
```

Enter the `make` command to run it.

After the build is finished, you can check the result of the static build.

```
$ file out/tools/x86_64-static-linux-musl/sysroot/bin/heif-convert
out/tools/x86_64-static-linux-musl/sysroot/bin/heif-convert: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, with debug_info, not stripped
```

## Packages

- Autoconf 2.71
- Automake 1.16.4
- Binutils 2.37
- Bison 3.7.6
- Gawk 5.1.0
- Gcc 11.2.0
- Gmp 6.2.1
- Libtool 2.4.6
- Linux 3.10.61
- M4 1.4.19
- Mpc 1.2.1
- Mpfr 4.1.0
- Musl 1.2.2
- OpenSSL 1.1.1d
- Pkgconf 1.8.0
- Zlib 1.2.11
