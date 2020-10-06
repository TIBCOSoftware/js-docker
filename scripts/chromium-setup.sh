#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.
# This script is used to set up the chromium at the time of container starting.

if hash yum 2>/dev/null; then
  PACKAGE_MGR="yum"
elif hash zypper 2>/dev/null; then
  PACKAGE_MGR="zypper"
elif hash rpm 2>/dev/null; then
  PACKAGE_MGR="rpm"
else
  PACKAGE_MGR="apt_get"
fi
echo "Installing packages with $PACKAGE_MGR"
case "$PACKAGE_MGR" in
"yum")
  yum -y install chromium
  ;;
"zypper")
  zypper -n install chromium
  ;;
"rpm")
  echo "Installed nothing via rpm"
  exit 1
  ;;
"apt_get")
  apt-get install -y --no-install-recommends chromium
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
# if chromium is installed, update JasperReports Server config.
if hash chrome 2>/dev/null; then
  CHROMIUM_CMD=chrome
elif hash chromium 2>/dev/null; then
  CHROMIUM_CMD=chromium
elif hash chromium-browser 2>/dev/null; then
  CHROMIUM_CMD=chromium-browser
else
  CHROMIUM_CMD=Not
fi

if [ "$CHROMIUM_CMD" != "Not" ]; then
  echo "$CHROMIUM_CMD available. Configuring JasperReports Server to use it"
  sed -i -r "s/^chrome.path=(.*)/chrome.path=$CHROMIUM_CMD/" \
  $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/js.config.properties
  cat $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/js.config.properties | grep chrome.path=
  echo 'net.sf.jasperreports.chrome.argument.no-sandbox=true' >>$CATALINA_HOME/webapps/jasperserver-pro//WEB-INF/classes/jasperreports.properties
else
  echo "Chromium not available. Headless browser functionality will fail."
fi
