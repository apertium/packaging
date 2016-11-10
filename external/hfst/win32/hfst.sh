patch_all
autoreconf -fi
./configure --enable-all-tools --with-unicode-handler=ICU --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
