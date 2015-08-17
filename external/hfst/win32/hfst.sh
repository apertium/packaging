patch_all
autoreconf -fi
./configure --enable-all-tools --with-unicode-handler=ICU --host=i686-w64-mingw32.shared --prefix=/opt/win32
./scripts/generate-cc-files.sh
export EXTRA_DEPS="libdl.dll zlib1.dll $EXTRA_DEPS"
