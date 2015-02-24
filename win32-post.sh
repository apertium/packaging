make clean
make -j8 || make -j8 || make -j8 || make -j8 || make
rm -rf /opt/win32-pkg/$PKG_NAME
make install DESTDIR=/opt/win32-pkg/$PKG_NAME
cd /opt/win32-pkg/$PKG_NAME/opt
for DEP in $EXTRA_DEPS
do
	cp -av /opt/mxe/usr/i686-w64-mingw32.shared/bin/$DEP win32/bin/
done
find . -type f -name '*.exe' -or -name '*.dll' | xargs -rn1 /opt/mxe/usr/bin/i686-w64-mingw32.shared-strip
find . -type f -name '*.a' | xargs -rn1 /opt/mxe/usr/bin/i686-w64-mingw32.shared-strip --strip-debug
mv win32 $PKG_NAME
#zip -9r $PKG_NAME-$PKG_VER.zip $PKG_NAME
7za a $PKG_NAME-$PKG_VER.7z $PKG_NAME
rm -fv ~apertium/public_html/win32/nightly/$PKG_NAME-[0-9]*.zip ~apertium/public_html/win32/nightly/$PKG_NAME-[0-9]*.7z
mv -v *.zip *.7z ~apertium/public_html/win32/nightly/
cd ~apertium/public_html/win32/nightly/
#ln -sfv $PKG_NAME-$PKG_VER.zip $PKG_NAME-latest.zip
ln -sfv $PKG_NAME-$PKG_VER.7z $PKG_NAME-latest.7z
chown -R apertium:apertium ~apertium/public_html/win32
