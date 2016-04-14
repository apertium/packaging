patch_all
autoreconf -fi
./configure --enable-all-tools --with-unicode-handler=ICU --host=x86_64-apple-darwin13 --prefix=/opt/osx
