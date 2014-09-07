#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

rm -rf /home/apertium/mock/*

cd /tmp/
for DISTRO in epel-6 epel-7 fedora-19 fedora-20
do
	for ARCH in i386 x86_64
	do
		if [ ! -f /etc/mock/$DISTRO-$ARCH.cfg ]; then
			echo "Skipping $DISTRO for $ARCH"
			continue
		fi
		echo "Initializing $DISTRO for $ARCH"
		mkdir -p /home/apertium/mock/$DISTRO/$ARCH/
		mock -r $DISTRO-$ARCH --clean --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v >/home/apertium/public_html/apt/logs/$DISTRO-$ARCH-init.log 2>&1
		mock -r $DISTRO-$ARCH --init --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v >>/home/apertium/public_html/apt/logs/$DISTRO-$ARCH-init.log 2>&1
		for PKG in gcc-c++ libicu-devel cmake cmake28 boost-devel wget ccache
		do
			echo "  Installing $PKG in $DISTRO for $ARCH"
			mock -r $DISTRO-$ARCH --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ --install $PKG -v >>/home/apertium/public_html/apt/logs/$DISTRO-$ARCH-init.log 2>&1
		done
	done
done
