#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

#mount | grep /var/cache/pbuilder/build/cow. | awk '{print $3}' | xargs -rn1 umount
rm -fv /var/cache/pbuilder/result/*
#rm -rf /var/cache/pbuilder/build/cow.*

cd /tmp/autopkg.*
for DISTRO in sid jessie stretch buster trusty xenial bionic cosmic
do
	if [[ "$3" == *",$DISTRO,"* ]]; then
		echo "Skipping $DISTRO"
		continue
	fi

	for ARCH in amd64 i386
	do
		echo "Reloading $BUILDTYPE for $DISTRO for $ARCH"
		echo "deb http://apertium.projectjj.com/apt/$BUILDTYPE $DISTRO main" > /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/etc/apt/sources.list.d/apertium.list
		echo 'apt-get -q -y update -o Dir::Etc::sourcelist="sources.list.d/apertium.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"' | cowbuilder --save --login --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ >/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1

		if [[ ! -s "/tmp/update-$DISTRO-$ARCH.log" ]]; then
			echo "Updating $DISTRO for $ARCH"
			cowbuilder --update --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ 2>&1 | tee "/tmp/update-$DISTRO-$ARCH.log" >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log
		else
			echo "Updating package list $DISTRO for $ARCH"
			echo 'apt-get -q -y update' | cowbuilder --save --login --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ 2>&1 | tee -a "/tmp/update-$DISTRO-$ARCH.log" >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log
		fi

		echo "Building $DISTRO for $ARCH"
		timeout 90m cowbuilder --build *$DISTRO*.dsc --basepath /var/cache/pbuilder/base-$DISTRO-$ARCH.cow/ >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1 &
		if [[ -n "$2" ]]; then
			break
		fi
	done

	for job in `jobs -p`
	do
		echo "Waiting for $job"
		wait $job
	done
done

for job in `jobs -p`
do
	echo "Waiting for $job"
	wait $job
done
