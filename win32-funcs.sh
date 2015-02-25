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
	pushd /tmp
	rm -rf $1
	7za x ~apertium/public_html/win32/nightly/$1-latest.7z
	rsync -av $1/* /opt/win32/
	rm -rf $1
	popd
}
