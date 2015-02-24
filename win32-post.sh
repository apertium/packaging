make -j8 || make -j8 || make
rm -rf /opt/win32-pkg/$PKG_NAME
make install DESTDIR=/opt/win32-pkg/$PKG_NAME
cd /opt/win32-pkg/$PKG_NAME/opt
find . -type f -name '*.exe' -or -name '*.dll' -or -name '*.a' -print0 | xargs -0n1 /opt/mxe/usr/bin/i686-w64-mingw32.shared-strip
mv win32 $PKG_NAME
zip -9r $PKG_NAME-$PKG_VER.zip $PKG_NAME
rm -fv ~apertium/public_html/win32/nightly/$PKG_NAME-[0-9]*.zip
mv -v *.zip ~apertium/public_html/win32/nightly/
cd ~apertium/public_html/win32/nightly/
ln -sfv $PKG_NAME-$1.zip $PKG_NAME-latest.zip
chown -R apertium:apertium ~apertium/public_html/win32
