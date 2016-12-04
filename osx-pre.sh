set -e

. osx-funcs.sh

export TARGET=x86_64-apple-darwin13
export PATH="/opt/osxcross/target/bin:$PATH"
export CC="$TARGET-clang"
export CXX="$TARGET-clang++-libc++"
export CPPFLAGS="-D__APPLE__"
export CFLAGS="-D__APPLE__"
export CXXFLAGS="-std=gnu++11 -stdlib=libc++ -D__APPLE__"
export LDFLAGS="-stdlib=libc++"
export PKG_CONFIG="/opt/osxcross/target/bin/$TARGET-pkg-config"
export OSXCROSS_PKG_CONFIG_PATH="/opt/osx/lib/pkgconfig"
export OSXCROSS_TARGET=darwin13
export OSXCROSS_MP_INC=1
export MACOSX_DEPLOYMENT_TARGET=10.9
export SDK_VERSION=10.9
export PKG_NAME=$1
export PKG_REV=$2
export PKG_VER=$3
export PKG_PATH=$4
export EXTRA_INST=""
rm -rf /opt/osx
rm -rf /opt/osx-pkg/$PKG_NAME
cd /opt/osx-build/$PKG_NAME
find . -type f -name 'Makefile*' -or -name '*.so' -or -name '*.dylib' -or -name '*.a' -or -name '*.la' -print0 | xargs -0n1 rm -rfv --
svn revert -R .
svn stat --no-ignore | grep '^[?I]' | xargs -n1 rm -rfv --
svn up -r$PKG_REV
svn cleanup
