#!/bin/bash

# Copyright © 2021-2023. Cloud Software Group, Inc. All Rights Reserved. Confidential & Proprietary.
# This file is subject to the license terms contained
# in the license file that is distributed with this file

if hash yum 2>/dev/null; then
 PACKAGE_MGR="yum"
else
 PACKAGE_MGR="apt_get"
fi
echo "Installing packages with $PACKAGE_MGR"


case "$PACKAGE_MGR" in
	"yum" )
		yum -y update &&
		yum -y install yum-utils unzip rsync shadow-utils
		yum autoremove -y &&
		yum clean all
		rm -rf /var/cache/yum
		;;
	"apt_get" )
		DEBIAN_FRONTEND=noninteractive apt-get -y update &&
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends apt-utils unzip rsync
		DEBIAN_FRONTEND=noninteractive apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
		rm -rf /var/lib/apt/lists/*
		;;
esac

