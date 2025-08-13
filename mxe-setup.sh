#!/bin/bash

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
	qt5 \
	dlfcn-win32 \
	libxml++ \
	xxhash \
	"MXE_TARGETS=x86_64-w64-mingw32.shared" \
	"MXE_PLUGIN_DIRS=plugins/gcc13"

ln -sf /usr/include/utf8 /opt/mxe/usr/x86_64-w64-mingw32.shared/include/utf8
ln -sf /usr/include/utf8.h /opt/mxe/usr/x86_64-w64-mingw32.shared/include/utf8.h
ln -sf /usr/include/utf8cpp /opt/mxe/usr/x86_64-w64-mingw32.shared/include/utf8cpp

export AUTOPKG_BITWIDTH=x86_64
export PATH="/opt/mxe/usr/bin:$PATH"

cd /opt/tmp
rm -rf rapidjson
git clone --depth 1 https://github.com/Tencent/rapidjson
cd rapidjson
$AUTOPKG_BITWIDTH-w64-mingw32.shared-cmake -DCMAKE_INSTALL_PREFIX=/opt/mxe/usr/$AUTOPKG_BITWIDTH-w64-mingw32.shared .
make -j
make install
