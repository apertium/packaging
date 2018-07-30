install_dep hfst-ospell
set +e
./cmake.sh -DCMAKE_TOOLCHAIN_FILE=/opt/osx.cmake --prefix=/opt/osx
set -e
