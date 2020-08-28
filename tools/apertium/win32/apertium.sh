patch_all
install_dep lttoolbox
autoreconf -fi
./configure --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
