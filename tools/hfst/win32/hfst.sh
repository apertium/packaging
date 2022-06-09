patch_all
install_dep foma
install_dep openfst
export ICU_CONFIG=no
autoreconf -fi
./configure --enable-all-tools --disable-static --with-readline --with-unicode-handler=icu --with-openfst-upstream --with-foma-upstream --host=$AUTOPKG_BITWIDTH-w64-mingw32.shared --prefix=/opt/win32
