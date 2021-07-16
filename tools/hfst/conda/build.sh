#!/bin/bash

if [[ `uname` == "Darwin" ]]; then
	if [[ `uname -m` == "arm64" ]]; then
		export MACOSX_DEPLOYMENT_TARGET=11.0
	else
		export MACOSX_DEPLOYMENT_TARGET=10.15
	fi
	export CXXFLAGS="-stdlib=libc++ -Wall -Wextra -O2 $CXXFLAGS"
	export LDFLAGS="-stdlib=libc++ -Wl,-headerpad_max_install_names $LDFLAGS"
fi

export VERBOSE=1 V=1
autoreconf -fvi
./configure --disable-static --enable-all-tools --with-readline --with-unicode-handler=icu --enable-python-bindings --prefix=${PREFIX}
make -j${CPU_COUNT}
#make -j1 check
find * -type f | xargs -rn1 ${BUILD}-strip -S -x >/dev/null 2>&1 || true
make -j${CPU_COUNT} install
