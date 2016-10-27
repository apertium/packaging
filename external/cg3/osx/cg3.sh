install_dep boost
install_dep icu
set +e
./cmake.sh -DCMAKE_TOOLCHAIN_FILE=/opt/osx.cmake --prefix=/opt/osx
set -e
mkdir -p /opt/osx-pkg/$PKG_NAME/opt/osx/bin/
ln -s vislcg3 /opt/osx-pkg/$PKG_NAME/opt/osx/bin/cg3
