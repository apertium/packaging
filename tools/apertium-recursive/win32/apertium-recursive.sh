install_dep lttoolbox
install_dep apertium
autoreconf -fi
./configure --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
