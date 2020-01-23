function patch_all {
	set +e
	for DIFF in $PKG_PATH/debian/patches/*.diff
	do
		patch -p1 < "$DIFF"
	done
	for DIFF in $PKG_PATH/win32/*.diff
	do
		patch -p1 < "$DIFF"
	done
	set -e
}

function install_dep {
	mkdir -p /opt/win32
	mkdir -pv /opt/autopkg/tmp/win32.$$
	pushd /opt/autopkg/tmp/win32.$$
	rm -rf $1
	echo "Installing $1"
	7za x -y ~apertium/public_html/$WINX/$BUILDTYPE/$1-latest.7z
	rsync -avu $1/* /opt/win32/
	popd
	rm -rf /opt/autopkg/tmp/win32.$$
}
