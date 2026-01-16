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
		yum -y install yum-utils wget unzip shadow-utils
		if [ "$INSTALL_CHROMIUM" == "true" ]; then
		  echo "WARNING! Cloud Software Group, Inc. is not liable for license violation of chromium"
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
                 # echo "WARNING! Cloud Software Group, Inc. is not liable for license violation of chromium"
		 # sleep 10
		 # apt-get -y install chromium
                 
                #Note: Users must provide consent to install Chrome by selecting INSTALL_CHROMIUM as true to acknowledge the terms.
                 echo "WARNING! Cloud Software Group, Inc. is not liable for license violation of chrome"
                 sleep 10
                 apt-get -y update
               apt-get install -y wget gnupg ca-certificates \
               libglib2.0-0 libnss3 libxss1 libgdk-pixbuf2.0-0 \
               libatk-bridge2.0-0 libgtk-3-0 fonts-liberation \
               libappindicator3-1 xdg-utils libu2f-udev libvulkan1
          # Add the Chrome repository
              wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
              echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
          # Install Chrome
              apt-get update
              apt-get install -y google-chrome-stable
              ln -s /opt/google/chrome/google-chrome /usr/bin/chromium

		fi
		apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false
		rm -rf /var/lib/apt/lists/*
		;;
esac

