#!/bin/bash

if [[ `whoami` != root ]]
then
	echo "You must run this Apertium install script as root, or via sudo!"
	exit -1
fi

CADENCE=nightly

echo "Cleaning up old install, if any..."
rm -fv /etc/apt/trusted.gpg.d/apertium* /etc/apt/preferences.d/apertium* /etc/apt/sources.list.d/apertium*

echo "Determining Debian/Ubuntu codename..."
P=`apt-cache policy`
P="$P "`lsb_release -c`"/dummy"
P="$P "`grep CODENAME /etc/lsb-release`"/dummy"
DISTRO="$1"
for D in sid stretch buster bullseye xenial bionic cosmic disco eoan
do
	if [[ $P == *$D/* ]]
	then
		DISTRO=$D
		echo "Found evidence of $D..."
	fi
done
if [[ -z "$DISTRO" ]]
then
	echo "No supported Debian or Ubuntu derivative detected - bailing out..."
	exit -1
fi
echo "Settling for $DISTRO - enabling the Apertium $CADENCE repo..."

echo "Installing Apertium GnuPG key to /etc/apt/trusted.gpg.d/apertium.gpg"
wget -q https://apertium.projectjj.com/apt/apertium-packaging.public.gpg -O /etc/apt/trusted.gpg.d/apertium.gpg

echo "Installing package override to /etc/apt/preferences.d/apertium.pref"
wget -q https://apertium.projectjj.com/apt/apertium.pref -O /etc/apt/preferences.d/apertium.pref

echo "Creating /etc/apt/sources.list.d/apertium.list"
echo "deb http://apertium.projectjj.com/apt/$CADENCE $DISTRO main" > /etc/apt/sources.list.d/apertium.list

echo "Running apt-get update..."
apt-get -qy update >/dev/null 2>&1

echo "All done - enjoy the packages! If you just want all core tools, do: sudo apt-get install apertium-all-dev"
