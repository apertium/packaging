patch -p1 < ${AUTOPKG_PKPATH}/debian/patches/openfst-cxx17.diff

autoreconf -fvi
./configure --enable-far --enable-pdt --enable-lookahead-fsts --enable-ngram-fsts --enable-const-fsts --enable-compact-fsts --enable-compress --enable-linear-fsts --enable-mpdt --enable-bin --disable-static
