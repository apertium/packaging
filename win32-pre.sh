function patch_all {
	if [[ -s "$PKG_PATH/debian/patches" ]]; then
		for DIFF in $PKG_PATH/debian/patches/*.diff
		do
			patch -p1 < "$DIFF"
		done
	fi
	for DIFF in $PKG_PATH/win32/*.diff
	do
		patch -p1 < "$DIFF"
	done
}

function install_dep {
	mkdir -p /opt/win32
	pushd /tmp
	rm -rf $1
	7za x ~apertium/public_html/win32/nightly/$1-latest.7z
	rsync -av $1/* /opt/win32/
	rm -rf $1
	popd
}

set -e

export PATH="/opt/mxe/usr/bin:$PATH"
export PKG_CONFIG="/opt/mxe/usr/i686-w64-mingw32.shared/bin/pkgconf"
export PKG_CONFIG_PATH="/opt/win32/lib/pkgconfig"
export PKG_NAME=$1
export PKG_REV=$2
export PKG_VER=$3
export PKG_PATH=$4
export EXTRA_DEPS="libstdc++-6.dll libgcc_s_sjlj-1.dll"
rm -rf /opt/win32
cd /opt/win32-build/$PKG_NAME
find . -type f -name '*.exe' -or -name '*.dll' -or -name '*.a' -or -name '*.la' -print0 | xargs -0n1 rm -rfv
svn revert -R .
svn stat | grep '?' | xargs -n1 rm -rfv
svn up -r$PKG_REV
