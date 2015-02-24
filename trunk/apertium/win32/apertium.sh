patch_all
install_dep lttoolbox
autoreconf -fi
./configure --host=i686-w64-mingw32.shared --prefix=/opt/win32
export EXTRA_DEPS="libxml2-2.dll libiconv-2.dll libpcre16-0.dll libpcre-1.dll libpcrecpp-0.dll libpcreposix-0.dll zlib1.dll $EXTRA_DEPS"
