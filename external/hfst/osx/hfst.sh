patch_all
autoreconf -fi
./configure --enable-all-tools --without-foma --with-unicode-handler=ICU --host=x86_64-apple-darwin12 --prefix=/opt/osx
./scripts/generate-cc-files.sh
