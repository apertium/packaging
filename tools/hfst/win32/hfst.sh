patch_all
autoreconf -fi
./configure --enable-all-tools --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
