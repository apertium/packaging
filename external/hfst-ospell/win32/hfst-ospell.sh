patch_all
autoreconf -fi
./configure --host=$BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
# --without-libxmlpp --with-tinyxml2
