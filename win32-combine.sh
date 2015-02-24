#!/bin/bash
set -e

. win32-funcs.sh

rm -rf /opt/win32

install_dep lttoolbox
install_dep apertium
install_dep apertium-lex-tools
install_dep hfst
install_dep hfst-ospell
install_dep cg3
install_dep cg3ide
install_dep trie-tools

cd /opt
rm -rf apertium-all-dev
mv win32 apertium-all-dev
7za a apertium-all-dev.7z apertium-all-dev
mv -fv apertium-all-dev.7z ~apertium/public_html/win32/nightly/
chown -R apertium:apertium ~apertium/public_html/win32
