install_dep lttoolbox
install_dep apertium
autoreconf -fi
export LTTOOLBOX_LIBS=`pkg-config --libs lttoolbox`
export LTTOOLBOX_CFLAGS=`pkg-config --cflags lttoolbox`
export APERTIUM_LIBS=`pkg-config --libs apertium`
export APERTIUM_CFLAGS=`pkg-config --cflags apertium`
./configure --host=x86_64-apple-darwin12 --prefix=/opt/osx
