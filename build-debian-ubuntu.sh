#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

export DEB_BUILD_OPTIONS="nocheck parallel=5 noddebs"

rm -fv /var/cache/pbuilder/result/*
rm -rf /var/cache/pbuilder/build/cow.*

cd /tmp/autopkg.*
# When rotating out sid, remember version check in rebuild-old.pl
for DISTRO in wheezy jessie sid stretch precise trusty vivid wily
do
	if [[ "$3" == *",$DISTRO,"* ]]; then
		echo "Skipping $DISTRO"
		continue
	fi

	for ARCH in amd64 i386
	do
		if [[ ! -s "/tmp/update-$DISTRO-$ARCH.log" ]]; then
			echo "Updating $DISTRO for $ARCH"
			cowbuilder --update --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ 2>&1 | tee "/tmp/update-$DISTRO-$ARCH.log" >/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log
		else
			echo "Updating package list $DISTRO for $ARCH"
			echo 'apt-get -q -y update' | cowbuilder --save --login --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ 2>&1 | tee -a "/tmp/update-$DISTRO-$ARCH.log" >/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log
		fi
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
