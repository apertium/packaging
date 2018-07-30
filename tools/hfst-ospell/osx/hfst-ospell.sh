patch_all
autoreconf -fi
./configure --host=${TARGET} --prefix=/opt/osx --disable-static --enable-zhfst --without-libxmlpp --without-tinyxml2
