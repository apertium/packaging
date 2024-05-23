#!/bin/bash
WHERE='/usr/local'
CADENCE=release
ARCH=`uname -m`

# Other locales may make Perl unhappy
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

set -e
mkdir -p /tmp/aad.$$
cd /tmp/aad.$$

echo "Downloading"
curl https://apertium.projectjj.com/osx/$CADENCE/$ARCH/apertium-all-dev.$ARCH.tar.bz2 > apertium-all-dev.tar.bz2

echo "Extracting"
tar -jxf apertium-all-dev.tar.bz2
cd apertium-all-dev
set +e
find . -type f -name '*.la' -exec rm -fv '{}' \;
set -e

echo "Fixing hardcoded paths"
FILES=`egrep -l '^#!/' $(grep -rl '/usr/local' bin)`
FILES="$FILES `grep -rl '/usr/local' lib/pkgconfig`"
for FILE in $FILES
do
        echo "Fixing $FILE"
        perl -pe "s@/usr/local@$WHERE@g;" -i.orig "$FILE"
done

echo "Removing /opt/local/bin hardcoded paths"
FILES=`egrep -l '^#!/' $(grep -rl '/opt/local/bin' bin)`
for FILE in $FILES
do
        echo "Fixing $FILE"
        perl -pe "s@/opt/local/bin/@@g;" -i.orig "$FILE"
done

echo "Copying files with sudo, so you may need to provide sudo password here:"
sudo mkdir -p "$WHERE/"
sudo cp -af * "$WHERE/"
sudo chmod -R uga+r "$WHERE"

echo "Cleaning up"
cd /tmp
rm -rf /tmp/aad.$$

if [[ "$PATH" != *"$WHERE/bin"* ]]; then
	echo "$WHERE/bin is not in your PATH, so you should add this to your ~/.profile"
	echo '    export PATH="'$WHERE'/bin:$PATH"'
fi

echo "You may need to add these to your ~/.profile or ~/.zprofile or session:"
echo 'export PKG_CONFIG_PATH='$WHERE'/lib/pkgconfig:'$WHERE'/share/pkgconfig:${PKG_CONFIG_PATH}'
echo 'export ACLOCAL_PATH='$WHERE'/share/aclocal:${ACLOCAL_PATH}'

set GREP=`egrep '^export PYTHONPATH' ~/.profile ~/.zprofile 2>/dev/null | grep "$WHERE/lib/python3.12/site-packages"`
if [[ -z "$GREP" ]]; then
	echo ""
	echo "Adding PYTHONPATH to your ~/.zprofile and ~/.profile - you should start a new terminal"
	echo ""
	echo "export PYTHONPATH=\"\$PYTHONPATH:$WHERE/lib/python3.12/site-packages\"" >> ~/.zprofile
	echo "export PYTHONPATH=\"\$PYTHONPATH:$WHERE/lib/python3.12/site-packages\"" >> ~/.profile
fi

echo "All done."
