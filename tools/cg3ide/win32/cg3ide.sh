install_dep cg3
/opt/mxe/usr/$BITWIDTH-w64-mingw32.shared/qt5/bin/qmake cg3ide.pro PREFIX=/opt/win32
export EXTRA_INST="release/cg3ide.exe release/cg3processor.exe"

mkdir -pv /opt/$WINX-pkg/$PKG_NAME/opt/win32/bin
rsync -av /opt/win32/bin /opt/$WINX-pkg/$PKG_NAME/opt/win32/
rsync -av /opt/mxe/usr/$BITWIDTH-w64-mingw32.shared/qt5/plugins/platforms /opt/$WINX-pkg/$PKG_NAME/opt/win32/bin/
