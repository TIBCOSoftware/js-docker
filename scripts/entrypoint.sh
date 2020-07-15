#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# This script sets up and runs JasperReports Server on container start.
# Default "run" command, set in Dockerfile, executes run_jasperserver.
# Use jasperserver-pro-cmdline to initialize the repository database

# Sets script to fail if any command fails.
set -e

. /common-environment.sh

run_jasperserver() {

  # Apply customization zips if present
  apply_customizations

  test_database_connection
  
  # Because default_master.properties could change on any launch,
  # always do deploy-webapp-pro.

  execute_buildomatic deploy-webapp-pro

  # setup phantomjs
  config_phantomjs

  # If JRS_HTTPS_ONLY is set, sets JasperReports Server to
  # run only in HTTPS. Update keystore and password if given
  config_ports_and_ssl

  # Apply ERAMON customizations
  apply_eramon_customizations

  # start tomcat
  exec env JAVA_OPTS="$JAVA_OPTS" catalina.sh run
}



config_phantomjs() {
  # if phantomjs binary is present, update JasperReports Server config.
  if [[ -x "/usr/local/bin/phantomjs" ]]; then
    PATH_PHANTOM='\/usr\/local\/bin\/phantomjs'
    PATTERN1='com.jaspersoft.jasperreports'
    PATTERN2='phantomjs.executable.path'
    cd $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF
    sed -i -r "s/(.*)($PATTERN1.highcharts.$PATTERN2=)(.*)/\2$PATH_PHANTOM/" \
      classes/jasperreports.properties
    sed -i -r "s/(.*)($PATTERN1.fusion.$PATTERN2=)(.*)/\2$PATH_PHANTOM/" \
      classes/jasperreports.properties
    sed -i -r "s/(.*)(phantomjs.binary=)(.*)/\2$PATH_PHANTOM/" \
      js.config.properties
  elif [[ "$(ls -A /usr/local/share/phantomjs)" ]]; then
    echo "Warning: /usr/local/bin/phantomjs is not executable, \
but /usr/local/share/phantomjs exists. PhantomJS \
is not correctly configured."
  fi
}

config_ports_and_ssl() {
  #
  # pushing Tomcat to run on HTTP_PORT and HTTPS_PORT
  echo "Tomcat to run on HTTP on ${HTTP_PORT} and HTTPS on ${HTTPS_PORT}"
  sed -i "s/port=\"[0-9]\+\" protocol=\"HTTP\/1.1\"/port=\"${HTTP_PORT}\" protocol=\"HTTP\/1.1\"/" $CATALINA_HOME/conf/server.xml
  sed -i "s/redirectPort=\"[0-9]\+\"/redirectPort=\"${HTTPS_PORT}\"/" $CATALINA_HOME/conf/server.xml

  # if $JRS_HTTPS_ONLY is set in environment to true, disable HTTP support
  # in JasperReports Server.
  JRS_HTTPS_ONLY=${JRS_HTTPS_ONLY:-false}
  SERVER_XML_USE_SECURE=${SERVER_XML_USE_SECURE:-false}

  if "$JRS_HTTPS_ONLY" = "true" ; then
    echo "Setting HTTPS only within JasperReports Server"
    cd $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF
    xmlstarlet ed --inplace \
      -N x="http://java.sun.com/xml/ns/j2ee" -u \
      "//x:security-constraint/x:user-data-constraint/x:transport-guarantee"\
      -v "CONFIDENTIAL" web.xml
    sed -i "s/=http:\/\//=https:\/\//g" js.quartz.properties
    sed -i "s/8080/${HTTPS_PORT:-8443}/g" js.quartz.properties
  else
    echo "NOT! Setting HTTPS only within JasperReports Server. Should actually turn it off, but cannot."
    if "$SERVER_XML_USE_SECURE" = "true" ; then
        echo "Setting 8080 to go through secure connection"
        xmlstarlet ed --inplace --append "/Server/Service/Connector[@port='8080']" --type attr -n scheme -v "https" --append "/Server/Service/Connector[@port='8080']" --type attr -n secure -v "true" ${CATALINA_HOME}/conf/server.xml
    fi
  fi

  SSL_CERT_PATH=${SSL_CERT_PATH:-${MOUNTS_HOME}/ssl-certificate}

  if [ -d "$SSL_CERT_PATH" ]; then
	  CERT_PATH_FILES=`find $SSL_CERT_PATH -iname ".keystore*" \
		-exec readlink -f {} \;`
	  
	  # update the keystore and password if there
	  if [[ $CERT_PATH_FILES -ne 0 ]]; then
		  # will only be one, if at all
		  for keystore in $CERT_PATH_FILES; do
			if [[ -f "$keystore" ]]; then
			  echo "Deploying SSL Keystore $keystore"
			  cp "${keystore}" /root
			  xmlstarlet ed --inplace --subnode "/Server/Service/Connector[@port='${HTTPS_PORT:-8443}']" --type elem \ 
					--var connector-ssl '$prev' \
				--update '$connector-ssl' --type attr -n port -v "${HTTPS_PORT:-8443}" \
				--update '$connector-ssl' --type attr -n keystoreFile  -v "/root/${keystore}" \
				--update '$connector-ssl' --type attr -n keystorePass  -v "${KS_PASSWORD:-changeit}" \
				${CATALINA_HOME}/conf/server.xml
			  echo "Deployed SSL ${keystore} keystore"
			fi
		  done
	  else
		  # update existing server.xml. could have been overwritten by customization
		  # xmlstarlet ed --inplace --subnode "/Server/Service/Connector[@port='${HTTPS_PORT:-8443}']" --type elem \ 
		  #		--var connector-ssl '$prev' \
		  #	--update '$connector-ssl' --type attr -n port -v "${HTTPS_PORT:-8443}" \
		  #		--update '$connector-ssl' --type attr -n keystorePass  -v "${KS_PASSWORD}" \
		  #		--update '$connector-ssl' --type attr -n keystoreFile  -v "/root/.keystore.p12" \
		  #		${CATALINA_HOME}/conf/server.xml
		  echo "No .keystore files. Did not update SSL"
	  fi

  # end if $SSL_CERT_PATH exists.
  fi

}


apply_customizations() {
  # unpack zips (if exist) from path
  # ${MOUNTS_HOME}/customization
  # to JasperReports Server web application path
  # $CATALINA_HOME/webapps/jasperserver-pro/
  # file sorted with natural sort
  JRS_CUSTOMIZATION=${JRS_CUSTOMIZATION:-${MOUNTS_HOME}/customization}
  if [ -d "$JRS_CUSTOMIZATION" ]; then
	  echo "Deploying Customizations from $JRS_CUSTOMIZATION"

	  JRS_CUSTOMIZATION_FILES=`find $JRS_CUSTOMIZATION -iname "*zip" \
		-exec readlink -f {} \; | sort -V`
	  # find . -path ./lower -prune -o -name "*txt"
	  for customization in $JRS_CUSTOMIZATION_FILES; do
		if [[ -f "$customization" ]]; then
		  if unzip -l $customization | grep install.sh ; then
			echo "Installing ${customization##*/}"
			mkdir -p "/tmp/jrs-installs/${customization##*/}"
			unzip -o -q "$customization" -d "/tmp/jrs-installs/${customization##*/}"
			cd "/tmp/jrs-installs/${customization##*/}"
			chmod +x -R *.sh
			./install.sh
			cd ..
			rm -rf "${customization##*/}"
		  else
			echo "Unzipping $customization into JasperReports Server webapp"
			unzip -o -q "$customization" \
				-d $CATALINA_HOME/webapps/jasperserver-pro/
		  fi
		fi
	  done
  fi
  
  TOMCAT_CUSTOMIZATION=${TOMCAT_CUSTOMIZATION:-${MOUNTS_HOME}/tomcat-customization}
  if [ -d "$TOMCAT_CUSTOMIZATION" ]; then
	  echo "Deploying Tomcat Customizations from $TOMCAT_CUSTOMIZATION"
	  TOMCAT_CUSTOMIZATION_FILES=`find $TOMCAT_CUSTOMIZATION -iname "*zip" \
		-exec readlink -f {} \; | sort -V`
	  for customization in $TOMCAT_CUSTOMIZATION_FILES; do
		if [[ -f "$customization" ]]; then
			echo "Unzipping $customization into Tomcat"
			unzip -o -q "$customization" \
				-d $CATALINA_HOME
		fi
	  done
	fi
}

apply_eramon_customizations() {
    echo "Adjusting JasperReports Server Settings for ERAMON"
    cd $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF
    # set session timeout to 0 to enable never being logged out
    xmlstarlet ed -L -N x="http://java.sun.com/xml/ns/javaee" -u "//x:session-timeout" --value 0 web.xml
    # enable saving to host system
    xmlstarlet ed -L -N b="http://www.springframework.org/schema/beans" -u "//b:property[@name='enableSaveToHostFS']/@value" --value true applicationContext.xml

    echo "Adjusting mail settings"
    cd $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF

    SMTP_MAIL_SERVER=${SMTP_MAIL_SERVER:-mail.example.com}
    SMTP_MAIL_USER=${SMTP_MAIL_USER}
    SMTP_MAIL_PASSWORD=${SMTP_MAIL_PASSWORD}
    SMTP_MAIL_FROM=${SMTP_MAIL_FROM:-reporting@example.com}
    SMTP_MAIL_DEPLOYMENT_URI=${SMTP_MAIL_DEPLOYMENT_URI:-http://localhost:8080/jasperserver-pro}

    sed -i "/report.scheduler.web.deployment.uri/c\report.scheduler.web.deployment.uri=$SMTP_MAIL_DEPLOYMENT_URI" js.quartz.properties
    sed -i "/report.scheduler.mail.sender.host/c\report.scheduler.mail.sender.host=$SMTP_MAIL_SERVER" js.quartz.properties
    sed -i "/report.scheduler.mail.sender.username/c\report.scheduler.mail.sender.username=$SMTP_MAIL_USER" js.quartz.properties
    sed -i "/report.scheduler.mail.sender.password/c\report.scheduler.mail.sender.password=$SMTP_MAIL_PASSWORD" js.quartz.properties
    sed -i "/report.scheduler.mail.sender.from/c\report.scheduler.mail.sender.from=$SMTP_MAIL_FROM" js.quartz.properties
}

echo "about to initialize deploy properties"

initialize_deploy_properties

echo "deploy properties initialized"

case "$1" in
  run)
    shift 1
    run_jasperserver "$@"
    ;;
  *)
    exec "$@"
esac

