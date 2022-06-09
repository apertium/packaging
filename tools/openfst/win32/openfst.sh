patch -p1 < ${AUTOPKG_PKPATH}/win32/openfst-mingw.diff

autoreconf -fvi
./configure --enable-far --enable-pdt --enable-lookahead-fsts --enable-ngram-fsts --enable-const-fsts --enable-compact-fsts --enable-compress --enable-linear-fsts --enable-mpdt --enable-bin --disable-static --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win32

sed -i.bak -e "s/\(allow_undefined=\)yes/\1no/" libtool
