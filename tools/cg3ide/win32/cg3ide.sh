install_dep cg3
/opt/mxe/usr/$AUTOPKG_BITWIDTH-w64-mingw32.shared/qt5/bin/qmake cg3ide.pro PREFIX=/opt/win32
export EXTRA_INST="cg3ide.exe cg3processor.exe"

mkdir -pv /opt/$AUTOPKG_WINX-pkg/$PKG_NAME/opt/win32/bin
rsync -av /opt/win32/bin /opt/$AUTOPKG_WINX-pkg/$PKG_NAME/opt/win32/
rsync -av /opt/mxe/usr/$AUTOPKG_BITWIDTH-w64-mingw32.shared/qt5/plugins/platforms /opt/$AUTOPKG_WINX-pkg/$PKG_NAME/opt/win32/bin/
