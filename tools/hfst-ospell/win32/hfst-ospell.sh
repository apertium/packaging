autoreconf -fi
./configure --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win32 --disable-static --enable-zhfst --without-libxmlpp --without-tinyxml2
