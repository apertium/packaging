export LDFLAGS="-L/usr/local/lib -lfst $LDFLAGS"
autoreconf -fvi
./configure --enable-all-tools --disable-static --with-readline --enable-python-bindings
