#!/bin/bash

cd "$AUTOPKG_BUILDPATH"
find . -type f -perm +0100 -or -type f -name '*.dylib' | while read F; do
	E=$(grep -l "libcg3.1.dylib" "$F")$(grep -l "libfoma.0.dylib" "$F")
	if [ -z "$E" ]; then
		continue
	fi

	echo "$F"
	install_name_tool -change '@rpath/libcg3.1.dylib' '/usr/local/lib/libcg3.1.dylib' "$F" 2>/dev/null
	install_name_tool -change '@rpath/libfoma.0.dylib' '/usr/local/lib/libfoma.0.dylib' "$F" 2>/dev/null
done
