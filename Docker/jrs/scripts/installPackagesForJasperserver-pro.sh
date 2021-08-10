#!/bin/bash

if hash yum 2>/dev/null; then
 PACKAGE_MGR="yum"
else
 PACKAGE_MGR="apt_get"
fi
echo "Installing packages with $PACKAGE_MGR"


case "$PACKAGE_MGR" in
	"yum" )
		yum -y update &&
		yum -y install yum-utils wget unzip shadow-utils
		if [ "$INSTALL_CHROMIUM" == "true" ]; then
		  echo "WARNING! For Chromium installation Tibco is not responsible for License violation"
		  sleep 10
		  amazon-linux-extras install epel -y
		  yum -y install chromium
		fi
		yum autoremove -y &&
		yum clean all
		rm -rf /var/cache/yum
		;;
	"apt_get" )
		apt-get -y update &&
		apt-get install -y --no-install-recommends apt-utils unzip wget
		if [ "$INSTALL_CHROMIUM" == "true" ]; then
		  echo "WARNING! For Chromium installation Tibco is not responsible for License violation"
		  sleep 10
		  apt-get -y install chromium
		fi
		apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
		rm -rf /var/lib/apt/lists/*
		;;
esac

