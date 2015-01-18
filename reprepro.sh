#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

rm -f /home/apertium/public_html/apt/logs/$1/reprepro.log
for DISTRO in wheezy jessie sid precise trusty utopic vivid
do
	echo "reprepro $DISTRO" >> /home/apertium/public_html/apt/logs/$1/reprepro.log
	reprepro -b /home/apertium/public_html/apt/nightly/ includedeb $DISTRO /var/cache/pbuilder/result/*$DISTRO*.deb 2>&1 | tee -a /home/apertium/public_html/apt/logs/$1/reprepro.log
done

rm -rf /home/apertium/public_html/apt/nightly/source/$1
mkdir -pv /home/apertium/public_html/apt/nightly/source/$1/
cp -av /tmp/autopkg.*/*.dsc /home/apertium/public_html/apt/nightly/source/$1/
cp -av /tmp/autopkg.*/*.changes /home/apertium/public_html/apt/nightly/source/$1/
cp -av /tmp/autopkg.*/*.tar.bz2 /home/apertium/public_html/apt/nightly/source/$1/

chown -R apertium:apertium /home/apertium
