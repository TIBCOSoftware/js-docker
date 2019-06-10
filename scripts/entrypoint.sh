#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# This script sets up and runs JasperReports Server on container start.
# Default "run" command, set in Dockerfile, executes run_jasperserver.
# If webapps/jasperserver-pro does not exist, run_jasperserver 
# redeploys webapp. If "jasperserver" database does not exist,
# run_jasperserver redeploys minimal database.
# Additional "init" only calls init_database, which will try to recreate 
# database and fail if DB exists.

# Sets script to fail if any command fails.
set -e

initialize_deploy_properties() {
  # If environment is not set, uses default values for postgres
  DB_USER=${DB_USER:-postgres}
  DB_PASSWORD=${DB_PASSWORD:-postgres}
  DB_HOST=${DB_HOST:-postgres}
  DB_PORT=${DB_PORT:-5432}
  DB_NAME=${DB_NAME:-jasperserver}
  FOODMART_DB_NAME=${FOODMART_DB_NAME:-foodmart}
  SUGARCRM_DB_NAME=${SUGARCRM_DB_NAME:-sugarcrm}
  POSTGRES_JDBC_DRIVER_VERSION=${POSTGRES_JDBC_DRIVER_VERSION-42.2.5}

  # Default_master.properties. Modify according to
  # JasperReports Server documentation.
  cat >/usr/src/jasperreports-server/buildomatic/default_master.properties\
<<-_EOL_
appServerType=tomcat
appServerDir=$CATALINA_HOME
dbType=postgresql
dbHost=$DB_HOST
dbUsername=$DB_USER
dbPassword=$DB_PASSWORD
dbPort=$DB_PORT
js.dbName=$DB_NAME
foodmart.dbName=$FOODMART_DB_NAME
sugarcrm.dbName=$SUGARCRM_DB_NAME
webAppName=jasperserver-pro
maven.jdbc.version=$POSTGRES_JDBC_DRIVER_VERSION
_EOL_

  JRS_DEPLOY_CUSTOMIZATION=${JRS_DEPLOY_CUSTOMIZATION:-/usr/local/share/jasperserver-pro/deploy-customization}

  if [[ -f "$JRS_DEPLOY_CUSTOMIZATION/default_master_additional.properties" ]]; then
    cat $JRS_DEPLOY_CUSTOMIZATION/default_master_additional.properties >> /usr/src/jasperreports-server/buildomatic/default_master.properties
  fi
  
  # Get the desired version of the PostgreSQL JDBC driver if we don't have it
  
  if [ ! "$(ls -A $CATALINA_HOME/lib/postgresql-$POSTGRES_JDBC_DRIVER_VERSION.jar)" ]; then
    wget \
      "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_DRIVER_VERSION}.jar"  \
      -P /usr/src/jasperreports-server/buildomatic/conf_source/db/postgresql/jdbc --no-verbose
  fi
}

setup_jasperserver() {

  # execute buildomatic js-ant targets for installing/configuring
  # JasperReports Server.
  
  cd /usr/src/jasperreports-server/buildomatic/
  
  for i in $@; do
    # Default deploy-webapp-pro attempts to remove
    # $CATALINA_HOME/webapps/jasperserver-pro path.
    # This behaviour does not work if mounted volumes are used.
    # Using unzip to populate webapp directory and non-destructive
    # targets for configuration
    if [ $i == "deploy-webapp-pro" ]; then
      ./js-ant \
        set-pro-webapp-name \
        deploy-webapp-datasource-configs \
        deploy-jdbc-jar \
        -DwarTargetDir=$CATALINA_HOME/webapps/jasperserver-pro
    else
      # warTargetDir webaAppName are set as
      # workaround for database configuration regeneration
      ./js-ant $i \
        -DwarTargetDir=$CATALINA_HOME/webapps/jasperserver-pro
    fi
  done
}

run_jasperserver() {
  initialize_deploy_properties
  
  # If the JDBC driver is not present in Tomcat or not the right version,
  # do deploy-webapp-pro.

  if [ ! "$(ls -A $CATALINA_HOME/lib/postgresql-$POSTGRES_JDBC_DRIVER_VERSION.jar)" ]; then
    # clean out any old driver
    rm -f $CATALINA_HOME/lib/postgresql-*.jar
    setup_jasperserver deploy-webapp-pro
  elif [[ ${JRS_DBCONFIG_REGEN} = "true" ]]; then

	# force regeneration of database configuration within the WAR and Tomcat.
	# This will allow to change DB configuration for an existing container.
	
    rm $CATALINA_HOME/lib/postgresql-*.jar
	setup_jasperserver deploy-webapp-datasource-configs deploy-jdbc-jar
  fi
    
  # Wait for PostgreSQL.
  retry_postgresql

  # if jasperserver database not present - setup database
  if [[ `test_postgresql -l | grep -i ${DB_NAME:-jasperserver} | wc -l` < 1 \
    ]]; then
	init_database
  fi

  config_license

  # setup phantomjs
  config_phantomjs

  # Apply customization zips if present
  apply_customizations

  # If JRS_HTTPS_ONLY is set, sets JasperReports Server to
  # run only in HTTPS. Update keystore and password if given
  config_ssl

  # start tomcat
  catalina.sh run
}

init_database() {
  # wait for PostgreSQL
  retry_postgresql
  # run only db creation targets
  setup_jasperserver set-pro-webapp-name create-js-db init-js-db-pro import-minimal-pro
  
  # Only install the samples if explicitly requested
  if [[ ${JRS_LOAD_SAMPLES:-false} = "true" ]]; then
    # if foodmart database not present - setup database
	if [[ `test_postgresql -l | grep -i ${FOODMART_DB_NAME:-foodmart} | wc -l` < 1 \
		]]; then
		setup_jasperserver create-foodmart-db \
						load-foodmart-db \
						update-foodmart-db
	fi

    # if sugarcrm database not present - setup database
	if [[ `test_postgresql -l | grep -i ${SUGARCRM_DB_NAME:-sugarcrm} | wc -l` < 1 \
		]]; then
		setup_jasperserver create-sugarcrm-db \
						load-sugarcrm-db 
	fi
	
	setup_jasperserver import-sample-data-pro
  fi
}

config_license() {
  # if license file does not exist, copy evaluation license.
  # Non-default location (~/ or /root) used to allow
  # for storing license in a volume. To update license
  # replace license file, restart container
  JRS_LICENSE_FINAL=${JRS_LICENSE:-/usr/local/share/jasperserver-pro/license}
  echo "License directory $JRS_LICENSE_FINAL"
  if [ ! -f "$JRS_LICENSE_FINAL/jasperserver.license" ]; then
	echo "Used internal evaluation license"
    cp /usr/src/jasperreports-server/jasperserver.license ~
	#\
    #  /usr/local/share/jasperserver-pro/license
  else
    echo "Used license at $JRS_LICENSE_FINAL"
	cp $JRS_LICENSE_FINAL/jasperserver.license ~
  fi
}

test_postgresql() {
  export PGPASSWORD=${DB_PASSWORD:-postgres}
  psql -h ${DB_HOST:-postgres} -p ${DB_PORT:-5432} -U ${DB_USER:-postgres} $@
}

retry_postgresql() {
	# Retry 5 times to check PostgreSQL is accessible.
	for retry in {1..5}; do
	  if test_postgresql; then
		echo "PostgreSQL accepting connections and logging in to host ${DB_HOST:-postgres}"
		break
	  elif [[ $retry = 5 ]]; then
		echo "PostgreSQL at host ${DB_HOST:-postgres} not accessible or cannot log in!"
		echo "##### Exiting #####"
		exit 1
	  else
		echo "Sleeping to try PostgreSQL connection again..." && sleep 15
	  fi
	done
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

config_ssl() {
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

  KEYSTORE_PATH=${KEYSTORE_PATH:-/usr/local/share/jasperserver-pro/keystore}
  if [ -d "$KEYSTORE_PATH" ]; then
	  echo "Keystore update path $KEYSTORE_PATH"

	  KEYSTORE_PATH_FILES=`find $KEYSTORE_PATH -iname ".keystore*" \
		-exec readlink -f {} \;`
	  
	  # update the keystore and password if there
	  if [[ $KEYSTORE_PATH_FILES -ne 0 ]]; then
		  # will only be one, if at all
		  for keystore in $KEYSTORE_PATH_FILES; do
			if [[ -f "$keystore" ]]; then
			  echo "Deploying Keystore $keystore"
			  cp "${keystore}" /root
			  xmlstarlet ed --inplace --subnode "/Server/Service/Connector[@port='${HTTPS_PORT:-8443}']" --type elem \ 
					--var connector-ssl '$prev' \
				--update '$connector-ssl' --type attr -n port -v "${HTTPS_PORT:-8443}" \
				--update '$connector-ssl' --type attr -n keystoreFile  -v "/root/${keystore}" \
				--update '$connector-ssl' --type attr -n keystorePass  -v "${KS_PASSWORD:-changeit}" \
				${CATALINA_HOME}/conf/server.xml
			  echo "Deployed ${keystore} keystore"
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

  # end if $KEYSTORE_PATH exists.
  fi

}


apply_customizations() {
  # unpack zips (if exist) from path
  # /usr/local/share/jasperserver-pro/customization
  # to JasperReports Server web application path
  # $CATALINA_HOME/webapps/jasperserver-pro/
  # file sorted with natural sort
  JRS_CUSTOMIZATION=${JRS_CUSTOMIZATION:-/usr/local/share/jasperserver-pro/customization}
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
  
  TOMCAT_CUSTOMIZATION=${TOMCAT_CUSTOMIZATION:-/usr/local/share/jasperserver-pro/tomcat-customization}
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
  
  CLUSTERED=${CLUSTERED:-false}
  
  # because context.xml is updated by setup_jasperserver above for the JNDI settings,
  # we need to delete the Manager tag here
  # other clustering settings will need to be in customizations and tomcat-customizations
  if "$CLUSTERED" = "true" ; then
    xmlstarlet ed --inplace -d "/Context/Manager" \
	  $CATALINA_HOME/webapps/jasperserver-pro/META-INF/context.xml
  fi  
}

case "$1" in
  run)
    shift 1
    run_jasperserver "$@"
    ;;
  init)
    init_database
    ;;
  *)
    exec "$@"
esac

