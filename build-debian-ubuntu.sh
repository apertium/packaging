#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

export DEB_BUILD_OPTIONS="nocheck $DEB_BUILD_OPTIONS"

rm -fv /var/cache/pbuilder/result/*
rm -rf /var/cache/pbuilder/build/cow.*

cd /tmp/autopkg.*
for DISTRO in wheezy jessie sid precise trusty utopic vivid
do
	if [[ "$3" == *",$DISTRO,"* ]]; then
		echo "Skipping $DISTRO"
		continue
	fi

	for ARCH in i386 amd64
	do
		echo "Updating $DISTRO for $ARCH"
		cowbuilder --update --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ >/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1
		echo "Building $DISTRO for $ARCH"
		cowbuilder --build *$DISTRO*.dsc --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1 &
		if [[ -n "$2" ]]; then
			break
		fi
	done
done

for job in `jobs -p`
do
	echo "Waiting for $job"
	wait $job
done
