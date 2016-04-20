#!/bin/bash
set -e

apt-get -qy update -o Dir::Etc::sourcelist="sources.list.d/apertium-nightly.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
apt-get -qfy install $(aptitude search '~O apertium' | egrep -o 'apertium-\w+-\w+' | sort | uniq)
