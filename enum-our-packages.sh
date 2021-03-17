#!/bin/bash
egrep '^(Package|Provides):' $(find . -type f -name control) | egrep -o '[^ ]+$' | sort | uniq
