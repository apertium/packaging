autoreconf -fi
./configure --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32 --disable-static --enable-zhfst --without-libxmlpp --without-tinyxml2
