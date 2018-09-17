#!/bin/bash
set -e

apt-get -qy update -o Dir::Etc::sourcelist="sources.list.d/apertium-nightly.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
apt-get -qfy install cg3
apt-get -qfy install $(aptitude search '~O apertium' | egrep -o 'apertium-\w+-\w+' | grep -v lex-tools | grep -v all-dev | sort | uniq)
apt-get -qfy install giella-kal
# apt-get -qfy install $(aptitude search '~O apertium' | grep 'single language' | egrep -o '(apertium|giella)-\w+' | sort | uniq)

set +e
su - apertium -c 'screen -r beta-apy -X quit && nice -n20 screen -dmS beta-apy /home/apertium/apertium-apy-beta/run-apy.sh'
su - katersat -c '~/workbench/inc/sanity-check.php'
