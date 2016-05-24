patch_all
autoreconf -fi
./configure --host=i686-w64-mingw32.shared --prefix=/opt/win32 --without-libxmlpp --with-tinyxml2
