function patch_all {
	set +e
	for DIFF in $PKG_PATH/debian/patches/*.diff
	do
		patch -p1 < "$DIFF"
	done
	for DIFF in $PKG_PATH/osx/*.diff
	do
		patch -p1 < "$DIFF"
	done
	set -e
}

function install_dep {
	mkdir -p /opt/osx
	pushd /tmp
	rm -rf $1
	echo "Installing $1"
	7za x -y ~apertium/public_html/osx/$BUILDTYPE/$1-latest.7z
	rsync -avu $1/* /opt/osx/
	rm -rf $1
	popd
}
