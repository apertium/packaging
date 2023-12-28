#!/bin/bash
find . -type f -name '*.exe' -or -name '*.dll' | grep -v 7z | xargs -rn1 /opt/mxe/usr/bin/$AUTOPKG_BITWIDTH-w64-mingw32.shared-strip
find . -type f -name '*.exe' -or -name '*.dll' | grep -v 7z | xargs -rn1 chmod uga+x
find . -type f -name '*.a' | xargs -rn1 /opt/mxe/usr/bin/$AUTOPKG_BITWIDTH-w64-mingw32.shared-strip --strip-debug
find . -type f -name '*.la' | xargs -rn1 rm -f 2>/dev/null
