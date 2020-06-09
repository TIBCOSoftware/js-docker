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

# installing JasperReports Server web app
if [ "$PACKAGE_MGR" = "yum" ]; then
	yum -y update
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
	yum -y install curl gnupg jq kubectl
else
	apt-get update
	apt-get install -y apt-transport-https curl gnupg jq
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list
	apt-get update
	apt-get install -y kubectl
	#rm -rf /var/lib/apt/lists/*
fi
