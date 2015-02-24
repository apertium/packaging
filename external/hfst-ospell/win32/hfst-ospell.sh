patch_all
autoreconf -fi
./configure --host=i686-w64-mingw32.shared --prefix=/opt/win32
export EXTRA_DEPS="libbz2.dll liblzma-5.dll libglibmm-2.4-1.dll libglib-2.0-0.dll libgmodule-2.0-0.dll libgobject-2.0-0.dll libsigc-2.0-0.dll libintl-8.dll libpcre-1.dll libffi-6.dll libxml++-2.6-2.dll libxml2-2.dll libiconv-2.dll libarchive-13.dll zlib1.dll $EXTRA_DEPS"
