#!/bin/bash
WHERE='/usr/local'
CADENCE=release

# Other locales may make Perl unhappy
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

PKG="$1"

set -e
mkdir -p /tmp/aad.$$
cd /tmp/aad.$$

echo "Downloading"
curl "https://apertium.projectjj.com/osx/nightly/data.php?deb=$PKG" > pkg.deb

echo "Extracting"
ar x pkg.deb data.tar.gz
tar -zxf data.tar.gz
cd usr

if [[ -e "share/apertium/modes" ]]; then
	echo "Fixing hardcoded paths"
	FILES=`grep -rl '/usr/share/' share/apertium/modes`
	for FILE in $FILES
	do
		echo "Fixing $FILE"
		perl -pe "s@/usr/share/@$WHERE/share/@g;" -i.orig "$FILE"
	done
fi

echo "Copying files with sudo, so you may need to provide sudo password here:"
sudo mkdir -p "$WHERE/"
sudo cp -af * "$WHERE/"
sudo chmod -R uga+r "$WHERE"

echo "Cleaning up"
cd /tmp
rm -rf /tmp/aad.$$

echo "You can now run the installed modes via apertium -d $WHERE/share/apertium xxx-yyy"

echo "All done."
