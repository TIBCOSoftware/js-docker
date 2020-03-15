#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

if hash yum 2>/dev/null; then
 #echo "yum found"
 PACKAGE_MGR="yum"
else
 #echo "yum not found, using apt-get"
 PACKAGE_MGR="apt_get"
fi

echo "Installing packages with $PACKAGE_MGR"

if [ ! -z $1 ] && [ "$1" = "cmdline" ] ; then
	# installing JasperReports Server command line
	if [ "$PACKAGE_MGR" = "yum" ]; then
		yum -y update
		yum -y install yum-utils wget unzip
	else
		apt-get update
		apt-get install -y --no-install-recommends apt-utils unzip wget 
		rm -rf /var/lib/apt/lists/*
	fi
else
	# installing JasperReports Server web app
	if [ "$PACKAGE_MGR" = "yum" ]; then
		yum -y update
		yum -y install yum-utils wget unzip tar bzip2
		wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
			-O /tmp/epel-release-latest-7.noarch.rpm --no-verbose 
		yum -y install /tmp/epel-release-latest-7.noarch.rpm
		yum -y install xmlstarlet
	else
		apt-get update
		apt-get install -y --no-install-recommends apt-utils unzip xmlstarlet
		#apt-get install -y unzip xmlstarlet 
		rm -rf /var/lib/apt/lists/*
	fi
fi
