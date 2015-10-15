patch_all
install_dep lttoolbox
autoreconf -fi
./configure --host=i686-w64-mingw32.shared --prefix=/opt/win32
