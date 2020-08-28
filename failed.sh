#!/bin/bash
# Copyright (C) 2014, Apertium Project Management Committee <apertium-pmc@dlsi.ua.es>
# Licensed under the GNU GPL version 2 or later; see http://www.gnu.org/licenses/

rm -rf /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/failed
mkdir -pv /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/failed/
cp -av --reflink=auto $AUTOPKG_AUTOPATH/*.dsc /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/failed/
cp -av --reflink=auto $AUTOPKG_AUTOPATH/*.changes /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/failed/
cp -av --reflink=auto $AUTOPKG_AUTOPATH/*.tar.bz2 /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1/failed/

chown -R apertium:apertium /home/apertium/public_html/apt/$AUTOPKG_BUILDTYPE/source/$1
