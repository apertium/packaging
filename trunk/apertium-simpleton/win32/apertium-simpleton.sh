/opt/mxe/usr/i686-w64-mingw32.shared/qt5/bin/qmake apertium-simpleton.pro PREFIX=/opt/win32
QT5="../qt5/bin"
export EXTRA_DEPS="icudt54.dll icuin54.dll icuio54.dll icuuc54.dll libharfbuzz-0.dll libpng16-16.dll libpcre16-0.dll libpcre-1.dll libiconv-2.dll libfreetype-6.dll libglib-2.0-0.dll libbz2.dll libintl-8.dll zlib1.dll $QT5/Qt5Core.dll $QT5/Qt5Gui.dll $QT5/Qt5Widgets.dll $QT5/Qt5Network.dll $EXTRA_DEPS"
export EXTRA_INST="release/apertium-simpleton.exe"

mkdir -pv /opt/win32-pkg/$PKG_NAME/opt/win32/bin
rsync -av /opt/win32/bin /opt/win32-pkg/$PKG_NAME/opt/win32/
rsync -av /opt/mxe/usr/i686-w64-mingw32.shared/qt5/plugins/platforms /opt/win32-pkg/$PKG_NAME/opt/win32/bin/
