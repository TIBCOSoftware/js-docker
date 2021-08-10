#! /bin/bash
set -e
#echo 'net.sf.jasperreports.chrome.argument.no-sandbox=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties
#echo 'net.sf.jasperreports.chrome.argument.disable-dev-shm-usage=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties
exec "$@"
