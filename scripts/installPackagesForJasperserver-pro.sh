#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

if hash yum 2>/dev/null; then
 #echo "yum found"
 PACKAGE_MGR="yum"
elif hash zypper 2>/dev/null; then
 PACKAGE_MGR="zypper"
elif hash rpm 2>/dev/null; then
 PACKAGE_MGR="rpm"
else
 #echo "other package managers not found, using apt-get"
 PACKAGE_MGR="apt_get"
fi
echo "Installing packages with $PACKAGE_MGR"

case "$PACKAGE_MGR" in
	"yum" )
		yum -y update
		yum -y install yum-utils wget unzip tar bzip2
		wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
			-O /tmp/epel-release-latest-7.noarch.rpm --no-verbose 
		yum -y install /tmp/epel-release-latest-7.noarch.rpm
		yum -y install xmlstarlet chromium
		;;
	"zypper" )
		zypper refresh
		zypper -n install wget unzip tar bzip2 
		wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
			-O /tmp/epel-release-latest-7.noarch.rpm --no-verbose 
		zypper -n install /tmp/epel-release-latest-7.noarch.rpm
		zypper -n install xmlstarlet chromium
		zypper clean -a
		;;
	"rpm" )
		echo "Installed nothing via rpm"
		exit 1
		;;
	"apt_get" )
		apt-get update
		apt-get install -y --no-install-recommends apt-utils unzip xmlstarlet chromium
		rm -rf /var/lib/apt/lists/*
		;;
esac

if hash chrome 2>/dev/null; then
  echo Using chrome
  chrome -version
elif hash chromium 2>/dev/null; then
  echo Using chromium
  chromium -version
elif hash chromium-browser 2>/dev/null; then
  echo Using chromium-browser
  chromium-browser -version
else
  echo Chromium not installed. Exiting
  exit 1
fi
