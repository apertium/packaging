#!/bin/bash

function pkg_msi {
	pushd /misc/spellers
	export WINX=$2
	./make_msi.pl $1
	mkdir -pv ~apertium/public_html/spellers/${BUILDTYPE}/
	rm -fv ~apertium/public_html/spellers/${BUILDTYPE}/$1*-$2*
	cp -av build/$1/*.msi ~apertium/public_html/spellers/${BUILDTYPE}/
	popd
	pushd ~apertium/public_html/spellers/${BUILDTYPE}/
	ln -sfv $1*-$2.msi $1-latest-$2.msi
	popd
}

function pkg_xpi {
	pushd /misc/spellers
	./make_xpi.pl $1
	mkdir -pv ~apertium/public_html/spellers/${BUILDTYPE}/
	rm -fv ~apertium/public_html/spellers/${BUILDTYPE}/$1*.xpi
	cp -av build/mozilla/$1*.xpi ~apertium/public_html/spellers/${BUILDTYPE}/
	popd
	pushd ~apertium/public_html/spellers/${BUILDTYPE}/
	ln -sfv $1*.xpi $1-latest.xpi
	popd
}

function combine_msi {
	pushd /tmp
	rm -f *.msi *.o
	rm -fv ~apertium/public_html/spellers/${BUILDTYPE}/$1*.exe
	cp -av ~apertium/public_html/spellers/${BUILDTYPE}/$1-[0-9]*-win32* 32.msi
	cp -av ~apertium/public_html/spellers/${BUILDTYPE}/$1-[0-9]*-win64* 64.msi
	/opt/mxe/usr/bin/i686-w64-mingw32.static-ld -r -b binary -o 32.o 32.msi
	/opt/mxe/usr/bin/i686-w64-mingw32.static-ld -r -b binary -o 64.o 64.msi
	EXE=`basename ~apertium/public_html/spellers/${BUILDTYPE}/$1-[0-9]*-win32* -win32.msi`
	/opt/mxe/usr/bin/i686-w64-mingw32.static-g++ -static -O3 -std=c++14 /misc/spellers/windows/setup.cpp 32.o 64.o -o $1.exe
	osslsigncode -pkcs12 '/root/.keys/2018-12-10 TDC Code Signing.p12' -readpass '/root/.keys/2018-12-10 TDC Code Signing.key' -t http://timestamp.verisign.com/scripts/timstamp.dll -in $1.exe -out "$EXE.exe"
	mv -v "$EXE.exe" ~apertium/public_html/spellers/${BUILDTYPE}/
	rm -f *.msi *.o
	popd
	pushd ~apertium/public_html/spellers/${BUILDTYPE}/
	ln -sfv $1*.exe $1-latest.exe
	popd
}

function pkg_spellers {
	pushd /misc/spellers
	svn up
	popd
	pkg_msi $1 win32
	pkg_msi $1 win64
	combine_msi $1
	pkg_xpi $1
	chown -R apertium:apertium ~apertium/public_html/spellers/${BUILDTYPE}
}
