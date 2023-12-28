patch -p1 < ${AUTOPKG_PKPATH}/windows/hfst-mingw.diff

#export ICU_CONFIG=no
autoreconf -fi
./configure --enable-all-tools --disable-static --with-readline --with-unicode-handler=icu --with-openfst-upstream --with-foma-upstream --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win-$AUTOPKG_BITWIDTH
