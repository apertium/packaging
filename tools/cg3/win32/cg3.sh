./cmake.sh -DCMAKE_TOOLCHAIN_FILE=/opt/mxe/usr/$BITWIDTH-w64-mingw32.shared/share/cmake/mxe-conf.cmake --prefix=/opt/win32
mkdir -p /opt/$WINX-pkg/$PKG_NAME/opt/win32/bin/
ln -s vislcg3.exe /opt/$WINX-pkg/$PKG_NAME/opt/win32/bin/cg3.exe
