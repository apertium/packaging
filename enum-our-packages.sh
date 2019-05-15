#!/bin/bash
egrep '^Package:' $(find . -type f -name control) | egrep -o '[^ ]+$' | sort | uniq
