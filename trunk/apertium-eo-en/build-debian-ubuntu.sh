#!/bin/bash

cd /tmp
rm -fv make-deb-source.pl
wget https://svn.code.sf.net/p/apertium/svn/branches/packaging/trunk/apertium-eo-en/make-deb-source.pl -O make-deb-source.pl
chmod +x *.pl
./make-deb-source.pl -m 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>'

rm -fv /var/cache/pbuilder/result/*
mkdir -p /home/apertium/public_html/apt/logs/apertium-eo-en/

cd /tmp/autopkg.*
for DISTRO in wheezy jessie sid precise saucy trusty utopic
do
	echo "Updating $DISTRO for i386"
	cowbuilder --update --basepath /var/cache/pbuilder/base-$DISTRO-i386.cow/ >/home/apertium/public_html/apt/logs/apertium-eo-en/$DISTRO-i386.log
	echo "Building $DISTRO for i386"
	cowbuilder --build *$DISTRO*.dsc --basepath /var/cache/pbuilder/base-$DISTRO-i386.cow/ >>/home/apertium/public_html/apt/logs/apertium-eo-en/$DISTRO-i386.log 2>&1 &
done

for job in `jobs -p`
do
	echo "Waiting for $job"
	wait $job
done

rm -f /home/apertium/public_html/apt/logs/apertium-eo-en/reprepro.log
for DISTRO in wheezy jessie sid precise saucy trusty utopic
do
	echo "reprepro $DISTRO" >> /home/apertium/public_html/apt/logs/apertium-eo-en/reprepro.log
	reprepro -b /home/apertium/public_html/apt/nightly/ includedeb $DISTRO /var/cache/pbuilder/result/*$DISTRO*.deb 2>&1 | tee -a /home/apertium/public_html/apt/logs/apertium-eo-en/reprepro.log
done

chown -R apertium:apertium /home/apertium/public_html/apt
