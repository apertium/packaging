#!/bin/bash

cd /tmp
rm -fv make-deb-source.pl
wget https://svn.code.sf.net/p/apertium/svn/branches/packaging/trunk/apertium-eo-en/make-deb-source.pl -O make-deb-source.pl
chmod +x *.pl
./make-deb-source.pl -m 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>' -e 'Apertium Automaton <apertium-packaging@lists.sourceforge.net>'

rm -fv /var/cache/pbuilder/result/*
mkdir -p /home/apertium/public_html/apt/logs/apertium-eo-en/

cd /tmp/autopkg.*
echo "Updating trusty for amd64"
cowbuilder --update --no-cowdancer-update --basepath /var/cache/pbuilder/base-trusty-amd64.cow/
echo "Building trusty for amd64"
time cowbuilder --build *.dsc --basepath /var/cache/pbuilder/base-trusty-amd64.cow/ 2>&1 | tee /home/apertium/public_html/apt/logs/apertium-eo-en/trusty-amd64.log

rm -f /home/apertium/public_html/apt/logs/apertium-eo-en/reprepro.log
echo "reprepro" >> /home/apertium/public_html/apt/logs/apertium-eo-en/reprepro.log
reprepro -b /home/apertium/public_html/apt/data/ includedeb data /var/cache/pbuilder/result/*_all.deb 2>&1 | tee -a /home/apertium/public_html/apt/logs/apertium-eo-en/reprepro.log

chown -R apertium:apertium /home/apertium/public_html/apt
