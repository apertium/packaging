install_dep lttoolbox
install_dep hfst
autoreconf -fi
./configure --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
