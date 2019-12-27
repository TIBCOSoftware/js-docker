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

  test_database_connection
  
  # Because default_master.properties could change on any launch,
  # always do deploy-webapp-pro.

  execute_buildomatic deploy-webapp-pro

  config_license

  # setup phantomjs
  config_phantomjs

  # Apply customization zips if present
  apply_customizations

  # If JRS_HTTPS_ONLY is set, sets JasperReports Server to
  # run only in HTTPS. Update keystore and password if given
  config_ports_and_ssl

  # Set Java options for Tomcat.
  # using G1GC - default Java GC in later versions of Java 8
  
  # setting heap based on info:
  # https://medium.com/adorsys/jvm-memory-settings-in-a-container-environment-64b0840e1d9e 
  # https://stackoverflow.com/questions/49854237/is-xxmaxramfraction-1-safe-for-production-in-a-containered-environment
  # https://www.oracle.com/technetwork/java/javase/8u191-relnotes-5032181.html
  
  # Assuming we are using a Java 8 version beyond 8u191, we can use the Java 10+ JAVA_OPTS
  # for containers
  # Assuming a minimum of 3GB for the container => a max of 2.4GB for heap
  # defaults to 33/3% Min, 80% Max
  
  JAVA_MIN_RAM_PCT=${JAVA_MIN_RAM_PERCENTAGE:-33.3}
  JAVA_MAX_RAM_PCT=${JAVA_MAX_RAM_PERCENTAGE:-80.0}
  JAVA_OPTS="$JAVA_OPTS -XX:-UseContainerSupport -XX:MinRAMPercentage=$JAVA_MIN_RAM_PCT -XX:MaxRAMPercentage=$JAVA_MAX_RAM_PCT"
  
  echo "JAVA_OPTS = $JAVA_OPTS"
  # start tomcat
  exec env JAVA_OPTS="$JAVA_OPTS" catalina.sh run
}

config_license() {
  # if license file does not exist, copy evaluation license.
  # Non-default location (~/ or /root) used to allow
  # for storing license in a volume. To update license
  # replace license file, restart container
  JRS_LICENSE_FINAL=${JRS_LICENSE:-${MOUNTS_HOME}/license}
  echo "License directory $JRS_LICENSE_FINAL"
  if [ ! -f "$JRS_LICENSE_FINAL/jasperserver.license" ]; then
	echo "Used internal evaluation license"
    cp /usr/src/jasperreports-server/jasperserver.license ~
  else
    echo "Used license at $JRS_LICENSE_FINAL"
	cp $JRS_LICENSE_FINAL/jasperserver.license ~
  fi
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
		  echo "Unzipping $customization into JasperReports Server webapp"
		  unzip -o -q "$customization" \
			-d $CATALINA_HOME/webapps/jasperserver-pro/
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


initialize_deploy_properties

case "$1" in
  run)
    shift 1
    run_jasperserver "$@"
    ;;
  *)
    exec "$@"
esac

