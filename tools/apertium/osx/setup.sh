autoreconf -fvi
./configure --enable-python-bindings
# Hack for RPATH issue
mkdir -pv apertium/.libs
ln -sfv /usr/local/lib/liblttoolbox.3.dylib apertium/.libs/liblttoolbox.3.dylib
