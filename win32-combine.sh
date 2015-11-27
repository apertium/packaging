#!/bin/bash
set -e

. win32-funcs.sh

# Apertium all-dev
rm -rf /opt/win32
install_dep lttoolbox
install_dep apertium
install_dep apertium-lex-tools
install_dep hfst
install_dep hfst-ospell
install_dep cg3ide
install_dep cg3
install_dep trie-tools

cd /opt
rm -rf apertium-all-dev
mv win32 apertium-all-dev
7za a apertium-all-dev.7z apertium-all-dev
mv -fv apertium-all-dev.7z ~apertium/public_html/win32/nightly/
rm -rf apertium-all-dev

# CG-3 IDE
rm -rf /opt/win32
install_dep cg3ide
install_dep cg3

cd /opt
rm -rf cg3ide
mv win32 cg3ide
7za a cg3ide.7z cg3ide
mv -fv cg3ide.7z ~apertium/public_html/win32/nightly/cg3ide-[0-9]*
rm -rf cg3ide

chown -R apertium:apertium ~apertium/public_html/win32
