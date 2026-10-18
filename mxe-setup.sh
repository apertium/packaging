#!/bin/bash

apt-get update
# MXE dependencies
apt-get install --no-install-recommends autoconf automake autopoint bash bison bzip2 flex g++ g++-multilib gettext git gperf intltool libc6-dev-i386 libclang-dev libgdk-pixbuf-xlib-2.0-dev libltdl-dev libgl-dev libpcre2-dev libssl-dev libtool-bin libxml-parser-perl lzip make openssl p7zip-full patch perl python3 python3-mako python3-packaging python3-pkg-resources python3-setuptools python-is-python3 ruby sed sqlite3 unzip wget xz-utils
# Apertium et al. dependencies
apt-get install --no-install-recommends libutfcpp-dev python3-yaml libjson-perl libcarp-always-perl libipc-system-simple-perl rsync ssh zip libxml2-utils xsltproc

cd /opt/mxe
git pull --all --rebase --autostash

make -j11 \
	gcc \
	boost \
	icu4c \
	libarchive \
	libtool \
	pcre \
	libxslt \
	pkgconf \
	tinyxml2 \
	libzip \
	sqlite \
	readline \
	termcap \
	qt6-qt5compat \
	dlfcn-win32 \
	libxml++ \
	xxhash \
	"MXE_TARGETS=x86_64-w64-mingw32.shared" \
	"MXE_PLUGIN_DIRS=plugins/gcc16"

ln -sf /usr/include/utf8 /opt/mxe/usr/x86_64-w64-mingw32.shared/include/utf8
ln -sf /usr/include/utf8.h /opt/mxe/usr/x86_64-w64-mingw32.shared/include/utf8.h
ln -sf /usr/include/utf8cpp /opt/mxe/usr/x86_64-w64-mingw32.shared/include/utf8cpp

export AUTOPKG_BITWIDTH=x86_64
export PATH="/opt/mxe/usr/bin:$PATH"

cd /opt/tmp
rm -rf rapidjson
git clone --depth 1 https://github.com/Tencent/rapidjson
cd rapidjson
$AUTOPKG_BITWIDTH-w64-mingw32.shared-cmake -DRAPIDJSON_BUILD_CXX20=ON -DRAPIDJSON_BUILD_DOC=OFF -DRAPIDJSON_BUILD_EXAMPLES=OFF -DRAPIDJSON_BUILD_TESTS=OFF -DCMAKE_INSTALL_PREFIX=/opt/mxe/usr/$AUTOPKG_BITWIDTH-w64-mingw32.shared .
make -j
make install
