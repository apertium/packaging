install_dep lttoolbox
install_dep apertium
autoreconf -fi
./configure --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
export EXTRA_DEPS="libxml2-2.dll libiconv-2.dll zlib1.dll $EXTRA_DEPS"
