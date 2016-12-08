#!/bin/bash

function pkg_msi {
	pushd /misc/spellers
	WINX=$2
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

function pkg_spellers {
	pushd /misc/spellers
	svn up
	popd
	pkg_msi $1 win32
	pkg_msi $1 win64
	pkg_xpi $1
	chown -R apertium:apertium ~apertium/public_html/spellers/${BUILDTYPE}
}
