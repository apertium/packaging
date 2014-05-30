#!/bin/bash

cd /tmp
rm -fv make-deb-source.pl
wget https://svn.code.sf.net/p/apertium/svn/branches/packaging/trunk/apertium-br-fr/make-deb-source.pl -O make-deb-source.pl
chmod +x *.pl
./make-deb-source.pl -m 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>'

rm -fv /var/cache/pbuilder/result/*
mkdir -p /home/apertium/public_html/apt/logs/apertium-br-fr/

cd /tmp/autopkg.*
for DISTRO in wheezy jessie sid precise saucy trusty utopic
do
	echo "Updating $DISTRO for i386"
	cowbuilder --update --basepath /var/cache/pbuilder/base-$DISTRO-i386.cow/
	echo "Building $DISTRO for i386"
	time cowbuilder --build *$DISTRO*.dsc --basepath /var/cache/pbuilder/base-$DISTRO-i386.cow/ 2>&1 | tee /home/apertium/public_html/apt/logs/apertium-br-fr/$DISTRO-i386.log
done

rm -f /home/apertium/public_html/apt/logs/apertium-br-fr/reprepro.log
for DISTRO in wheezy jessie sid precise saucy trusty utopic
do
	echo "reprepro $DISTRO" >> /home/apertium/public_html/apt/logs/apertium-br-fr/reprepro.log
	reprepro -b /home/apertium/public_html/apt/nightly/ includedeb $DISTRO /var/cache/pbuilder/result/*$DISTRO*.deb 2>&1 | tee -a /home/apertium/public_html/apt/logs/apertium-br-fr/reprepro.log
done

chown -R apertium:apertium /home/apertium/public_html/apt
