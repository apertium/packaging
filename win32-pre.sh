export PATH="/opt/mxe/usr/bin:$PATH"
export PKG_CONFIG="/opt/mxe/usr/i686-w64-mingw32.shared/bin/pkgconf"
export PKG_CONFIG_PATH="/opt/win32/lib/pkgconfig"
export PKG_NAME=$1
export PKG_REV=$2
export PKG_VER=$3
export EXTRA_DEPS="libstdc++-6.dll libgcc_s_sjlj-1.dll"
cd /opt/win32-build/$PKG_NAME
find . -type f -name '*.exe' -or -name '*.dll' -or -name '*.a' -or -name '*.la' -print0 | xargs -0n1 rm -rfv
svn revert -R .
svn stat | grep '?' | xargs -n1 rm -rfv
svn up -r$PKG_REV
