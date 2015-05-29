patch_all
install_dep lttoolbox
autoreconf -fi
export APERTIUM_LIBS=`pkg-config --libs lttoolbox`
export APERTIUM_CFLAGS=`pkg-config --cflags lttoolbox`
./configure --host=x86_64-apple-darwin12 --prefix=/opt/osx
