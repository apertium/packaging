set -e

. win32-funcs.sh

export PATH="/opt/mxe/usr/bin:$PATH"
export PKG_CONFIG="/opt/mxe/usr/bin/$BITWIDTH-w64-mingw32.shared-pkg-config"
export PKG_CONFIG_PATH_${BITWIDTH}_w64_mingw32_shared="/opt/win32/lib/pkgconfig"
export PKG_NAME=$1
export PKG_REV=$2
export PKG_VER=$3
export PKG_PATH=$4
export EXTRA_DEPS="libstdc++-6.dll libgcc_s_*.dll"
export EXTRA_INST=""
export LDFLAGS="-fno-use-linker-plugin"
rm -rf /opt/win32
rm -rf /opt/$WINX-pkg/$PKG_NAME

if [[ "$BUILD_VCS" == "git" ]]; then
	rm -rf /opt/win32-build/$PKG_NAME
	cp -a --reflink=auto /opt/autopkg/tmp/git/$PKG_NAME.git /opt/win32-build/$PKG_NAME || git clone --shallow-submodules /opt/autopkg/repos/$PKG_NAME.git /opt/win32-build/$PKG_NAME
	cd /opt/win32-build/$PKG_NAME
else
	cd /opt/win32-build/$PKG_NAME
	find . -type f -name 'Makefile*' -or -name '*.exe' -or -name '*.dll' -or -name '*.a' -or -name '*.la' -print0 | xargs -0n1 rm -rfv --
	svn revert -R .
	svn stat --no-ignore | grep '^[?I]' | xargs -n1 rm -rfv --
	svn up -r$PKG_REV
	svn cleanup
fi
