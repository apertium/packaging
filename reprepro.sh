#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see https://www.gnu.org/licenses/

rm -f /home/apertium/public_html/apt/logs/$1/reprepro.log
for DISTRO in sid stretch buster bullseye bionic focal hirsute impish
do
	echo "reprepro $DISTRO" >> /home/apertium/public_html/apt/logs/$1/reprepro.log
	DISTRO_TRG=$DISTRO
	if [[ -n "$2" && "$3" == *",$DISTRO,"* ]]; then
		DISTRO=sid
		echo "True data-only, using $DISTRO pkg for $DISTRO_TRG" >> /home/apertium/public_html/apt/logs/$1/reprepro.log
	fi
	find $AUTOPKG_AUTOPATH -type f -name '*.deb' | grep "~$DISTRO" | xargs -rn1 reprepro -b /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/ includedeb $DISTRO_TRG 2>&1 | tee -a /home/apertium/public_html/apt/logs/$1/reprepro.log
#	find $AUTOPKG_AUTOPATH -type f -name '*.changes' | grep -v _source.changes | grep "~$DISTRO" | xargs -rn1 reprepro -b /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/ include $DISTRO_TRG 2>&1 | tee -a /home/apertium/public_html/apt/logs/$1/reprepro.log
#	find $AUTOPKG_AUTOPATH -type f -name '*.changes' | grep -v _source.changes | grep "~$DISTRO" | xargs -rn1 docker run --rm --network none -v /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/:/build/ -v /root/.gnupg/:/root/.gnupg/ reprepro reprepro -b /build/ include $DISTRO_TRG" 2>&1 | tee -a /home/apertium/public_html/apt/logs/$1/reprepro.log
done

rm -rf /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1
mkdir -pv /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/
cp -av --reflink=auto $AUTOPKG_AUTOPATH/*.dsc /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/
cp -av --reflink=auto $AUTOPKG_AUTOPATH/*.changes /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/
cp -av --reflink=auto $AUTOPKG_AUTOPATH/*.tar.bz2 /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/

chown -R apertium:apertium /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE
