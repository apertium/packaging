autoreconf -fi
./configure --host=i686-w64-mingw32.shared --prefix=/opt/win32
export EXTRA_DEPS="libxml2-2.dll libarchive-13.dll zlib1.dll $EXTRA_DEPS"
