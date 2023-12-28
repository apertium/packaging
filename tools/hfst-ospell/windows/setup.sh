autoreconf -fi
./configure --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win-$AUTOPKG_BITWIDTH --disable-static --enable-zhfst --without-libxmlpp --without-tinyxml2
