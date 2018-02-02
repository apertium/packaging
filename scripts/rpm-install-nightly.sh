#!/bin/bash

if [[ `whoami` != root ]]
then
	echo "You must run this Apertium install script as root, or via sudo!"
	exit -1
fi

CADENCE=nightly

echo "Determining Fedora/CentOS/RHEL/OpenSUSE version..."
P=`cat /etc/*-release`
DISTRO=
TOOL=yum
case $P in
	*Red*Hat*Enterprise*Linux*7*|*Scientific*Linux*7*|*CentOS*7*)
		DISTRO="CentOS_7"
		;;
	*Fedora*26*)
		DISTRO="Fedora_26"
		TOOL=dnf
		;;
	*Fedora*27*)
		DISTRO="Fedora_27"
		TOOL=dnf
		;;
	*openSUSE*Leap*42.2*)
		DISTRO="openSUSE_Leap_42.2"
		TOOL=zypper
		;;
	*openSUSE*Leap*42.3*)
		DISTRO="openSUSE_Leap_42.3"
		TOOL=zypper
		;;
	*openSUSE*Tumbleweed*)
		DISTRO="openSUSE_Tumbleweed"
		TOOL=zypper
		;;
esac

if [[ -z "$DISTRO" ]]
then
	echo "No supported RHEL, CentOS, Fedora, or OpenSUSE derivative detected - bailing out..."
	exit -1
fi
echo "Settling for $DISTRO - enabling the Apertium $CADENCE repo..."

URL="http://download.opensuse.org/repositories/home:/TinoDidriksen:/$CADENCE/$DISTRO/home:TinoDidriksen:$CADENCE.repo"
case $TOOL in
	yum|dnf)
		echo "Installing $URL to /etc/yum.repos.d/apertium-$CADENCE.repo..."
		rm -fv /etc/yum.repos.d/apertium*
		wget "$URL" -O /etc/yum.repos.d/apertium.repo
		echo "Running $TOOL updateinfo..."
		$TOOL updateinfo
		;;
	zypper)
		echo "Installing $URL via zypper..."
		zypper ar -f "$URL"
		echo "Running zypper refresh..."
		zypper refresh
		;;
esac

echo "All done - enjoy the packages! If you just want all core tools, do: sudo $TOOL install apertium-all-devel"
