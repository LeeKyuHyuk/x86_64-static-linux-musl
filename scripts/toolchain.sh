#!/bin/bash
#
# Toolchain build script
# Optional parameteres below:
set +h
set -o nounset
set -o errexit
umask 022

export LC_ALL=POSIX
export CONFIG_HOST=`echo ${MACHTYPE} | sed -e 's/-[^-]*/-cross/'`

export CFLAGS="-O2 -I$TOOLS_DIR/include"
export CPPFLAGS="-O2 -I$TOOLS_DIR/include"
export CXXFLAGS="-O2 -I$TOOLS_DIR/include"
export LDFLAGS="-L$TOOLS_DIR/lib -Wl,-rpath,$TOOLS_DIR/lib"

export PKG_CONFIG="$TOOLS_DIR/bin/pkg-config"
export PKG_CONFIG_SYSROOT_DIR="/"
export PKG_CONFIG_LIBDIR="$TOOLS_DIR/lib/pkgconfig:$TOOLS_DIR/share/pkgconfig"
export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1

CONFIG_PKG_VERSION="x86_64 2021.09"
CONFIG_BUG_URL="https://github.com/LeeKyuHyuk/x86_64-static-linux-musl/issues"

# End of optional parameters
function step() {
    echo -e "\e[7m\e[1m>>> $1\e[0m"
}

function success() {
    echo -e "\e[1m\e[32m$1\e[0m"
}

function error() {
    echo -e "\e[1m\e[31m$1\e[0m"
}

function extract() {
    case $1 in
        *.tgz) tar -zxf $1 -C $2 ;;
        *.tar.gz) tar -zxf $1 -C $2 ;;
        *.tar.bz2) tar -jxf $1 -C $2 ;;
        *.tar.xz) tar -Jxf $1 -C $2 ;;
    esac
}

function check_environment_variable {
    if ! [[ -d $SOURCES_DIR ]] ; then
        error "Please download tarball files!"
        error "Run 'make download'."
        exit 1
    fi
}

function check_tarballs {
    LIST_OF_TARBALLS="
        autoconf-2.71.tar.xz
        automake-1.16.4.tar.xz
        binutils-2.37.tar.xz
        bison-3.7.6.tar.xz
        gawk-5.1.0.tar.xz
        gcc-11.2.0.tar.xz
        gmp-6.2.1.tar.xz
        libtool-2.4.6.tar.xz
        linux-3.10.61.tar.xz
        m4-1.4.19.tar.xz
        mpc-1.2.1.tar.gz
        mpfr-4.1.0.tar.xz
        musl-1.2.2.tar.gz
        pkgconf-1.8.0.tar.xz
        zlib-1.2.11.tar.xz
    "

    for tarball in $LIST_OF_TARBALLS ; do
        if ! [[ -f $SOURCES_DIR/$tarball ]] ; then
            error "Can't find '$tarball'!"
            exit 1
        fi
    done
}

function do_strip {
    set +o errexit
    if [[ $CONFIG_STRIP_AND_DELETE_DOCS = 1 ]] ; then
        strip --strip-debug $TOOLS_DIR/lib/*
        strip --strip-unneeded $TOOLS_DIR/{,s}bin/*
        rm -rf $TOOLS_DIR/{,share}/{info,man,doc}
    fi
}

function timer {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local stime=$1
        etime=$(date '+%s')
        if [[ -z "$stime" ]]; then stime=$etime; fi
        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%02d:%02d:%02d' $dh $dm $ds
    fi
}

check_environment_variable
check_tarballs
total_build_time=$(timer)

step "[1/15] Create toolchain directory."
rm -rf $BUILD_DIR $TOOLS_DIR
mkdir -pv $BUILD_DIR $TOOLS_DIR
ln -svf . $TOOLS_DIR/usr

step "[2/15] Create the sysroot directory"
mkdir -pv $SYSROOT_DIR
ln -svf . $SYSROOT_DIR/usr
mkdir -pv $SYSROOT_DIR/lib
if [[ "$CONFIG_LINUX_ARCH" = "x86" ]] ; then
    ln -snvf lib $SYSROOT_DIR/lib32
fi
if [[ "$CONFIG_LINUX_ARCH" = "x86_64" ]] ; then
    ln -snvf lib $SYSROOT_DIR/lib64
fi

step "[3/15] Pkgconf 1.8.0"
extract $SOURCES_DIR/pkgconf-1.8.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/pkgconf-1.8.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --disable-dependency-tracking )
make -j$PARALLEL_JOBS -C $BUILD_DIR/pkgconf-1.8.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/pkgconf-1.8.0
cat > $TOOLS_DIR/bin/pkg-config << "EOF"
#!/bin/sh
PKGCONFDIR=$(dirname $0)
DEFAULT_PKG_CONFIG_LIBDIR=${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/lib/pkgconfig:${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/share/pkgconfig
DEFAULT_PKG_CONFIG_SYSROOT_DIR=${PKGCONFDIR}/../@STAGING_SUBDIR@
DEFAULT_PKG_CONFIG_SYSTEM_INCLUDE_PATH=${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/include
DEFAULT_PKG_CONFIG_SYSTEM_LIBRARY_PATH=${PKGCONFDIR}/../@STAGING_SUBDIR@/usr/lib
PKG_CONFIG_LIBDIR=${PKG_CONFIG_LIBDIR:-${DEFAULT_PKG_CONFIG_LIBDIR}} \
	PKG_CONFIG_SYSROOT_DIR=${PKG_CONFIG_SYSROOT_DIR:-${DEFAULT_PKG_CONFIG_SYSROOT_DIR}} \
	PKG_CONFIG_SYSTEM_INCLUDE_PATH=${PKG_CONFIG_SYSTEM_INCLUDE_PATH:-${DEFAULT_PKG_CONFIG_SYSTEM_INCLUDE_PATH}} \
	PKG_CONFIG_SYSTEM_LIBRARY_PATH=${PKG_CONFIG_SYSTEM_LIBRARY_PATH:-${DEFAULT_PKG_CONFIG_SYSTEM_LIBRARY_PATH}} \
	exec ${PKGCONFDIR}/pkgconf @STATIC@ "$@"
EOF
chmod 755 $TOOLS_DIR/bin/pkg-config
sed -i -e "s,@STAGING_SUBDIR@,$SYSROOT_DIR,g" $TOOLS_DIR/bin/pkg-config
sed -i -e "s,@STATIC@,," $TOOLS_DIR/bin/pkg-config
rm -rf $BUILD_DIR/pkgconf-1.8.0

step "[4/15] M4 1.4.19"
extract $SOURCES_DIR/m4-1.4.19.tar.xz $BUILD_DIR
( cd $BUILD_DIR/m4-1.4.19 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/m4-1.4.19
make -j$PARALLEL_JOBS install -C $BUILD_DIR/m4-1.4.19
rm -rf $BUILD_DIR/m4-1.4.19

step "[5/15] Libtool 2.4.6"
extract $SOURCES_DIR/libtool-2.4.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/libtool-2.4.6 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/libtool-2.4.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/libtool-2.4.6
rm -rf $BUILD_DIR/libtool-2.4.6

step "[6/15] Autoconf 2.71"
extract $SOURCES_DIR/autoconf-2.71.tar.xz $BUILD_DIR
( cd $BUILD_DIR/autoconf-2.71 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/autoconf-2.71
make -j$PARALLEL_JOBS install -C $BUILD_DIR/autoconf-2.71
rm -rf $BUILD_DIR/autoconf-2.71

step "[7/15] Automake 1.16.4"
extract $SOURCES_DIR/automake-1.16.4.tar.xz $BUILD_DIR
( cd $BUILD_DIR/automake-1.16.4 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/automake-1.16.4
make -j$PARALLEL_JOBS install -C $BUILD_DIR/automake-1.16.4
mkdir -p $SYSROOT_DIR/usr/share/aclocal
rm -rf $BUILD_DIR/automake-1.16.4

step "[8/15] Zlib 1.2.11"
extract $SOURCES_DIR/zlib-1.2.11.tar.xz $BUILD_DIR
( cd $BUILD_DIR/zlib-1.2.11 && ./configure --prefix=$TOOLS_DIR )
make -j1 -C $BUILD_DIR/zlib-1.2.11
make -j1 install -C $BUILD_DIR/zlib-1.2.11
rm -rf $BUILD_DIR/zlib-1.2.11

step "[9/15] Bison 3.7.6"
extract $SOURCES_DIR/bison-3.7.6.tar.xz $BUILD_DIR
( cd $BUILD_DIR/bison-3.7.6 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared )
make -j$PARALLEL_JOBS -C $BUILD_DIR/bison-3.7.6
make -j$PARALLEL_JOBS install -C $BUILD_DIR/bison-3.7.6
rm -rf $BUILD_DIR/bison-3.7.6

step "[10/15] Gawk 5.1.0"
extract $SOURCES_DIR/gawk-5.1.0.tar.xz $BUILD_DIR
( cd $BUILD_DIR/gawk-5.1.0 && \
    ./configure \
    --prefix=$TOOLS_DIR \
    --disable-static \
    --enable-shared \
    --without-readline \
    --without-mpfr )
make -j$PARALLEL_JOBS -C $BUILD_DIR/gawk-5.1.0
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gawk-5.1.0
rm -rf $BUILD_DIR/gawk-5.1.0

step "[11/15] Binutils 2.37"
extract $SOURCES_DIR/binutils-2.37.tar.xz $BUILD_DIR
mkdir -pv $BUILD_DIR/binutils-2.37/binutils-build
( cd $BUILD_DIR/binutils-2.37/binutils-build && \
    MAKEINFO=true \
    $BUILD_DIR/binutils-2.37/configure \
    --prefix=$TOOLS_DIR \
    --target=$CONFIG_TARGET \
    --disable-multilib \
    --disable-werror \
    --disable-shared \
    --enable-static \
    --with-sysroot=$SYSROOT_DIR \
    --enable-poison-system-directories \
    --disable-sim \
    --disable-gdb )
make -j$PARALLEL_JOBS configure-host -C $BUILD_DIR/binutils-2.37/binutils-build
make -j$PARALLEL_JOBS -C $BUILD_DIR/binutils-2.37/binutils-build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/binutils-2.37/binutils-build
rm -rf $BUILD_DIR/binutils-2.37

step "[12/15] Gcc 11.2.0 - Static"
extract $SOURCES_DIR/gcc-11.2.0.tar.xz $BUILD_DIR
extract $SOURCES_DIR/gmp-6.2.1.tar.xz $BUILD_DIR/gcc-11.2.0
mv -v $BUILD_DIR/gcc-11.2.0/gmp-6.2.1 $BUILD_DIR/gcc-11.2.0/gmp
extract $SOURCES_DIR/mpfr-4.1.0.tar.xz $BUILD_DIR/gcc-11.2.0
mv -v $BUILD_DIR/gcc-11.2.0/mpfr-4.1.0 $BUILD_DIR/gcc-11.2.0/mpfr
extract $SOURCES_DIR/mpc-1.2.1.tar.gz $BUILD_DIR/gcc-11.2.0
mv -v $BUILD_DIR/gcc-11.2.0/mpc-1.2.1 $BUILD_DIR/gcc-11.2.0/mpc
mkdir -pv $BUILD_DIR/gcc-11.2.0/gcc-static-build
( cd $BUILD_DIR/gcc-11.2.0/gcc-static-build && \
    MAKEINFO=missing \
    CFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    CXXFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    $BUILD_DIR/gcc-11.2.0/configure \
    --prefix=$TOOLS_DIR \
    --build=$CONFIG_HOST \
    --host=$CONFIG_HOST \
    --target=$CONFIG_TARGET \
    --disable-decimal-float \
    --disable-libatomic \
    --disable-libgomp \
    --disable-libmudflap \
    --disable-libquadmath \
    --disable-libssp \
    --disable-multilib \
    --disable-nls  \
    --disable-shared \
    --disable-threads \
    --enable-languages=c \
    --with-arch="$CONFIG_GCC_ARCH" \
    --with-bugurl="$CONFIG_BUG_URL" \
    --with-newlib \
    --with-pkgversion="$CONFIG_PKG_VERSION" \
    --with-sysroot=$SYSROOT_DIR \
    --without-headers )
make -j$PARALLEL_JOBS gcc_cv_libc_provides_ssp=yes all-gcc all-target-libgcc -C $BUILD_DIR/gcc-11.2.0/gcc-static-build
make -j$PARALLEL_JOBS install-gcc install-target-libgcc -C $BUILD_DIR/gcc-11.2.0/gcc-static-build
rm -rf $BUILD_DIR/gcc-11.2.0

step "[13/15] Linux 3.10.61 API Headers"
extract $SOURCES_DIR/linux-3.10.61.tar.xz $BUILD_DIR
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH mrproper -C $BUILD_DIR/linux-3.10.61
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH headers_check -C $BUILD_DIR/linux-3.10.61
make -j$PARALLEL_JOBS ARCH=$CONFIG_LINUX_ARCH INSTALL_HDR_PATH=$SYSROOT_DIR headers_install -C $BUILD_DIR/linux-3.10.61
rm -rf $BUILD_DIR/linux-3.10.61

step "[14/15] musl 1.2.2"
extract $SOURCES_DIR/musl-1.2.2.tar.gz $BUILD_DIR
mkdir $BUILD_DIR/musl-1.2.2/musl-build
( cd $BUILD_DIR/musl-1.2.2/musl-build && \
    $BUILD_DIR/musl-1.2.2/configure \
    CROSS_COMPILE="$TOOLS_DIR/bin/$CONFIG_TARGET-" \
    --prefix=/usr \
    --target=$CONFIG_TARGET \
    --enable-static )
make -j$PARALLEL_JOBS -C $BUILD_DIR/musl-1.2.2/musl-build
make -j$PARALLEL_JOBS DESTDIR=$SYSROOT_DIR install -C $BUILD_DIR/musl-1.2.2/musl-build
install -m 0644 -D $SUPPORT_DIR/musl/queue.h $SYSROOT_DIR/include/sys/queue.h
rm -rf $BUILD_DIR/musl-1.2.2

step "[15/15] Gcc 11.2.0 - Final"
extract $SOURCES_DIR/gcc-11.2.0.tar.xz $BUILD_DIR
extract $SOURCES_DIR/gmp-6.2.1.tar.xz $BUILD_DIR/gcc-11.2.0
mv -v $BUILD_DIR/gcc-11.2.0/gmp-6.2.1 $BUILD_DIR/gcc-11.2.0/gmp
extract $SOURCES_DIR/mpfr-4.1.0.tar.xz $BUILD_DIR/gcc-11.2.0
mv -v $BUILD_DIR/gcc-11.2.0/mpfr-4.1.0 $BUILD_DIR/gcc-11.2.0/mpfr
extract $SOURCES_DIR/mpc-1.2.1.tar.gz $BUILD_DIR/gcc-11.2.0
mv -v $BUILD_DIR/gcc-11.2.0/mpc-1.2.1 $BUILD_DIR/gcc-11.2.0/mpc
mkdir -v $BUILD_DIR/gcc-11.2.0/gcc-final-build
( cd $BUILD_DIR/gcc-11.2.0/gcc-final-build && \
    MAKEINFO=missing \
    CFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    CXXFLAGS_FOR_TARGET="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os" \
    $BUILD_DIR/gcc-11.2.0/configure \
    --prefix=$TOOLS_DIR \
    --build=$CONFIG_HOST \
    --host=$CONFIG_HOST \
    --target=$CONFIG_TARGET \
    --disable-libmudflap \
    --disable-multilib \
    --disable-nls \
	--disable-libmpx \
	--disable-libsanitizer \
    --enable-c99 \
    --enable-languages=c,c++ \
    --enable-long-long \
    --with-arch="$CONFIG_GCC_ARCH" \
    --with-bugurl="$CONFIG_BUG_URL" \
    --with-pkgversion="$CONFIG_PKG_VERSION" \
    --with-sysroot=$SYSROOT_DIR )
make -j$PARALLEL_JOBS AS_FOR_TARGET="$TOOLS_DIR/bin/$CONFIG_TARGET-as" LD_FOR_TARGET="$TOOLS_DIR/bin/$CONFIG_TARGET-ld" gcc_cv_libc_provides_ssp=yes -C $BUILD_DIR/gcc-11.2.0/gcc-final-build
make -j$PARALLEL_JOBS install -C $BUILD_DIR/gcc-11.2.0/gcc-final-build
for libstdc in libstdc++ ; do
    cp -dpvf $TOOLS_DIR/$CONFIG_TARGET/lib*/$libstdc.a $SYSROOT_DIR/usr/lib/ ;
done
for libstdc in libstdc++ ; do
    cp -dpvf $TOOLS_DIR/$CONFIG_TARGET/lib*/$libstdc.so* $SYSROOT_DIR/usr/lib/ ;
done
if [ ! -e $TOOLS_DIR/bin/$CONFIG_TARGET-cc ]; then
    ln -vf $TOOLS_DIR/bin/$CONFIG_TARGET-gcc $TOOLS_DIR/bin/$CONFIG_TARGET-cc
fi
rm -rf $BUILD_DIR/gcc-11.2.0

do_strip

success "\nTotal toolchain build time: $(timer $total_build_time)\n"