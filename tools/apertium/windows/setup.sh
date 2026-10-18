autoreconf -fi
./configure "CFLAGS=-std=c99" --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win-$AUTOPKG_BITWIDTH
