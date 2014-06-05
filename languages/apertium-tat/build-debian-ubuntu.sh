#!/bin/bash

./make-deb-source.pl -m 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>'

rm -fv /var/cache/pbuilder/result/*
mkdir -p /home/apertium/public_html/apt/logs/apertium-tat/

cd /tmp/autopkg.*
for DISTRO in wheezy jessie sid precise saucy trusty utopic
do
	echo "Updating $DISTRO for i386"
	cowbuilder --update --basepath /var/cache/pbuilder/base-$DISTRO-i386.cow/ >/home/apertium/public_html/apt/logs/apertium-tat/$DISTRO-i386.log
	echo "Building $DISTRO for i386"
	cowbuilder --build *$DISTRO*.dsc --basepath /var/cache/pbuilder/base-$DISTRO-i386.cow/ >>/home/apertium/public_html/apt/logs/apertium-tat/$DISTRO-i386.log 2>&1 &
done

for job in `jobs -p`
do
	echo "Waiting for $job"
	wait $job
done

rm -f /home/apertium/public_html/apt/logs/apertium-tat/reprepro.log
for DISTRO in wheezy jessie sid precise saucy trusty utopic
do
	echo "reprepro $DISTRO" >> /home/apertium/public_html/apt/logs/apertium-tat/reprepro.log
	reprepro -b /home/apertium/public_html/apt/nightly/ includedeb $DISTRO /var/cache/pbuilder/result/*$DISTRO*.deb 2>&1 | tee -a /home/apertium/public_html/apt/logs/apertium-tat/reprepro.log
done

chown -R apertium:apertium /home/apertium/public_html/apt
