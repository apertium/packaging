patch_all
autoreconf -fi
./configure --disable-static --enable-all-tools --with-unicode-handler=icu --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
