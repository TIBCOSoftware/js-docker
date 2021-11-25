#! /bin/bash

# Copyright (c) 2021-2021. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file

set -e
#echo 'net.sf.jasperreports.chrome.argument.no-sandbox=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties
#echo 'net.sf.jasperreports.chrome.argument.disable-dev-shm-usage=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties
exec "$@"
