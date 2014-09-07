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
		mkdir -p /home/apertium/mock/$DISTRO/$ARCH/
		rm -rf /var/lib/mock/$DISTRO-$ARCH/root/builddir/build
		echo "Updating $DISTRO for $ARCH"
		mock -r $DISTRO-$ARCH --no-clean --no-cleanup-after --update --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v >/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1
		echo "Installing dependencies $DISTRO for $ARCH"
		mock -r $DISTRO-$ARCH --no-clean --no-cleanup-after --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v --installdeps /home/apertium/rpmbuild/SRPMS/$1*.src.rpm >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1
		echo "Building $DISTRO for $ARCH"
		mock -r $DISTRO-$ARCH --no-clean --no-cleanup-after --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v /home/apertium/rpmbuild/SRPMS/$1*.src.rpm >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1 &
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

for DISTRO in epel-6 epel-7 fedora-19 fedora-20
do
	for ARCH in i386 x86_64
	do
		if ls /home/apertium/mock/$DISTRO/$ARCH/$1-*.rpm &>/dev/null; then
			continue
		fi
		if [ ! -f /etc/mock/$DISTRO-$ARCH.cfg ]; then
			continue
		fi
		echo "Failed build of $DISTRO for $ARCH - retrying"
		rm -rf /home/apertium/mock/$DISTRO/$ARCH/
		mkdir -p /home/apertium/mock/$DISTRO/$ARCH/
		rm -rf /var/lib/mock/$DISTRO-$ARCH/root/builddir/build
		echo "Updating $DISTRO for $ARCH"
		mock -r $DISTRO-$ARCH --no-clean --no-cleanup-after --update --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v >/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1
		echo "Installing dependencies $DISTRO for $ARCH"
		mock -r $DISTRO-$ARCH --no-clean --no-cleanup-after --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v --installdeps /home/apertium/rpmbuild/SRPMS/$1*.src.rpm >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1
		echo "Building $DISTRO for $ARCH"
		mock -r $DISTRO-$ARCH --no-clean --no-cleanup-after --resultdir=/home/apertium/mock/$DISTRO/$ARCH/ -v /home/apertium/rpmbuild/SRPMS/$1*.src.rpm >>/home/apertium/public_html/apt/logs/$1/$DISTRO-$ARCH.log 2>&1 &
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
