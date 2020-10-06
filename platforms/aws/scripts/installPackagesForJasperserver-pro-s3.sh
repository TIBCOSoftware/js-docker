#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
=======
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

if [ "$PACKAGE_MGR" = "yum" ]; then
	yum -y update
	yum -y install curl python3 python3-pip groff
else
# load AWS CLI
    apt-get update
    apt-get install -y --no-install-recommends apt-utils curl python3 python3-pip groff
    rm -rf /var/lib/apt/lists/*
fi

pip3 install awscli --upgrade
