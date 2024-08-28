#export ICU_CONFIG=no
autoreconf -fi
./configure --enable-all-tools --disable-static --with-readline --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win-$AUTOPKG_BITWIDTH
