patch_all
install_dep lttoolbox
autoreconf -fi
./configure --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
