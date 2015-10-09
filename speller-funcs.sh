#!/bin/bash

function pkg_spellers {
	pushd /misc/spellers
	svn up
	./make_msi.pl $1
	mkdir -pv ~apertium/public_html/spellers/
	rm -fv ~apertium/public_html/spellers/$1*
	cp -av build/$1/*.msi build/mozilla/$1*.xpi ~apertium/public_html/spellers/
	popd
	pushd ~apertium/public_html/spellers/
	ln -sfv $1*.msi $1-latest.msi
	ln -sfv $1*.xpi $1-latest.xpi
	popd
	chown -R apertium:apertium ~apertium/public_html/spellers
}
