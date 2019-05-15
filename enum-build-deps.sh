#!/bin/bash
find . -type f -name control | php -r 'while ($f = trim(fgets(STDIN))) { $f=file_get_contents($f); $f = preg_replace("~,\n\s*~s", ",", $f); echo $f; }' | grep Build-Depends | perl -wpne 's/Build-Depends:\s*//g; s/ \([^)]*\)//g; s/,/\n/g; s/\|/\n/g; s/[ \t]+//g;' | sort | uniq -c | sort -nr
