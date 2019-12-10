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
  DB_TYPE=${DB_TYPE:-postgresql}
  DB_USER=${DB_USER:-postgres}
  DB_PASSWORD=${DB_PASSWORD:-postgres}
  DB_HOST=${DB_HOST:-postgres}
  DB_NAME=${DB_NAME:-jasperserver}

  # Default_master.properties. Modify according to
  # JasperReports Server documentation.
  cat >/usr/src/jasperreports-server/buildomatic/default_master.properties\
<<-_EOL_
appServerType=tomcat
appServerDir=$CATALINA_HOME
dbType=$DB_TYPE
dbHost=$DB_HOST
dbUsername=$DB_USER
dbPassword=$DB_PASSWORD
js.dbName=$DB_NAME
foodmart.dbName=jasperserver_foodmart
sugarcrm.dbName=jasperserver_sugarcrm
admin.jdbcUrl=jdbc:mysql://$DB_HOST:$DB_PORT/jasperserver_connect_check
webAppName=jasperserver-pro
_EOL_

  # set the JDBC_DRIVER_VERSION if it is passed in.
  # Otherwise rely on the default maven.jdbc.version from the dbType
  if [ ! -z "$JDBC_DRIVER_VERSION" ]; then
    cat >> /usr/src/jasperreports-server/buildomatic/default_master.properties\
<<-_EOL_
maven.jdbc.version=$JDBC_DRIVER_VERSION
_EOL_
  elif [ "$DB_TYPE" = "postgresql" ]; then
    POSTGRES_JDBC_DRIVER_VERSION=${POSTGRES_JDBC_DRIVER_VERSION:-42.2.5}
    cat >> /usr/src/jasperreports-server/buildomatic/default_master.properties\
<<-_EOL_
maven.jdbc.version=$POSTGRES_JDBC_DRIVER_VERSION
_EOL_
  fi

  # set the DB_PORT if it is passed in.
  # Otherwise rely on the default port from the dbType
  if [ ! -z "$DB_PORT" ]; then
    cat >> /usr/src/jasperreports-server/buildomatic/default_master.properties\
<<-_EOL_
dbPort=$DB_PORT
_EOL_
  fi
  
  JRS_DEPLOY_CUSTOMIZATION=${JRS_DEPLOY_CUSTOMIZATION:-/usr/local/share/jasperserver-pro/deploy-customization}

  if [[ -f "$JRS_DEPLOY_CUSTOMIZATION/default_master_additional.properties" ]]; then
    # note that because these properties are at the end of the properties file
	# they will have precedence over the ones created above
    cat $JRS_DEPLOY_CUSTOMIZATION/default_master_additional.properties >> /usr/src/jasperreports-server/buildomatic/default_master.properties
  fi
}

setup_jasperserver() {

  # execute buildomatic js-ant targets for installing/configuring
  # JasperReports Server.
  
  cd /usr/src/jasperreports-server/buildomatic/
  
  for i in $@; do
    # Default buildomatic deploy-webapp-pro target attempts to remove
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
  init_databases
  
  # Because default_master.properties could change on any launch,
  # always do deploy-webapp-pro.

  setup_jasperserver deploy-webapp-pro

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

# tests connection to the configured repo database.
# could fail altogether, be missing the database or succeed
# do-install-upgrade-test does 2 connections
# - database specific admin database
# - js.dbName
# at least one attempt has to work to indicate the host is accessible
try_database_connection() {
  sawJRSDBName=false
  sawConnectionOK=0
      
  cd /usr/src/jasperreports-server/buildomatic/

  while read -r line
  do
	if [ -z "$line" ]; then
	  #echo "blank line"
	  continue
	fi
	# on subsequent tries, show the output
    if [ $1 -gt 1 ]; then
      echo $line
	fi
	if [[ $line == *"$DB_NAME"* ]]; then
	  sawJRSDBName=true
	elif [[ $line == *"Connection OK"* ]]; then
	  sawConnectionOK=$((sawConnectionOK + 1))
	fi
  done < <(./js-ant do-install-upgrade-test)

  if [ "$sawConnectionOK" -lt 1 ]; then
	echo "##### Failing! ##### Saw $sawConnectionOK OK connections, not at least 1"
    retval="fail"
  elif [ "$sawJRSDBName" = "false" ]; then
    retval="missing"
  else
    retval="OK"
  fi
}

test_database_connection() {
	# Retry 5 times to check PostgreSQL is accessible.
	for retry in {1..5}; do
	  try_database_connection $retry
	  #echo "test_connection returned $retval"
	  if [ "$retval" = "OK" -o "$retval" = "missing" ]; then
		echo "$DB_TYPE at host ${DB_HOST} accepting connections and logging in"
		break
	  elif [[ $retry = 5 ]]; then
		echo "$DB_TYPE at host ${DB_HOST} not accessible or cannot log in!"
		echo "##### Exiting #####"
		exit 1
	  else
		echo "Sleeping to try $DB_TYPE at host ${DB_HOST} connection again..." && sleep 15
	  fi
	done
}


# tests for jasperserver, foodmart and sugarcrm databases
# and creates them
init_databases() {

  test_database_connection
  
  badConnection=false
  
  sawJRSDBName="notyet"
  sawFoodmartDBName="notyet"
  sawSugarCRMDBName="notyet"
  
  sawConnectionOK=0
  
  currentDatabase=""
  
  JRS_LOAD_SAMPLES=${JRS_LOAD_SAMPLES:-false}
  #loadSamples=[[ "$1" = "samples" -o "$JRS_LOAD_SAMPLES" = "true" ]]
  echo "JRS_LOAD_SAMPLES $JRS_LOAD_SAMPLES, command $1" 
  
  cd /usr/src/jasperreports-server/buildomatic/
  
  while read -r line
  do
	if [ -z "$line" ]; then
	  #echo "blank line"
	  continue
	fi
	if [[ $line == *"$DB_NAME"* ]]; then
	  currentDatabase=$DB_NAME
	elif [[ $line == *"jasperserver_foodmart"* ]]; then
	  currentDatabase=jasperserver_foodmart
	elif [[ $line == *"jasperserver_sugarcrm"* ]]; then
	  currentDatabase=jasperserver_sugarcrm
	elif [[ $line == *"Database doesn"* ]]; then
		case "$currentDatabase" in
		  $DB_NAME )
			sawJRSDBName="no"
			;;
		  jasperserver_foodmart )
			sawFoodmartDBName="no"
			;;
		  jasperserver_sugarcrm )
			sawSugarCRMDBName="no"
			;;
		  *)
		esac
	elif [[ $line == *"Connection OK"* ]]; then
		case "$currentDatabase" in
		  $DB_NAME )
			sawJRSDBName="yes"
			;;
		  jasperserver_foodmart )
			sawFoodmartDBName="yes"
			;;
		  jasperserver_sugarcrm )
			sawSugarCRMDBName="yes"
			;;
		  *)
		esac
	    sawConnectionOK=$((sawConnectionOK + 1))
	fi
  done < <(./js-ant do-pre-install-test)
  
  if [ "$sawConnectionOK" -lt 1 ]; then
	echo "##### Exiting! ##### saw $sawConnectionOK OK connections, not at least 1"
    exit 1
  fi
  
  echo "Database init status: $DB_NAME : $sawJRSDBName foodmart: $sawFoodmartDBName  sugarcrm $sawSugarCRMDBName"
  if [ "$sawJRSDBName" = "no" ]; then
	  setup_jasperserver set-pro-webapp-name create-js-db init-js-db-pro import-minimal-pro
  else
    echo "$DB_NAME repository database already exists: not creating and loading"
  fi
	  
  # Only install the samples if explicitly requested
  if [ "$1" = "samples" -o "$JRS_LOAD_SAMPLES" = "true" ]; then
    echo "Samples load requested"
	# if foodmart database not present - setup database
	if [ "$sawFoodmartDBName" = "no" ]; then
		setup_jasperserver create-foodmart-db \
						load-foodmart-db \
						update-foodmart-db
	fi

	# if sugarcrm database not present - setup database
	if [ "$sawSugarCRMDBName" = "no" ]; then
		setup_jasperserver create-sugarcrm-db \
						load-sugarcrm-db 
	fi
	
	setup_jasperserver import-sample-data-pro
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

import() {
  initialize_deploy_properties
  # Import from the passed in list of volumes
  
  cd /usr/src/jasperreports-server/buildomatic/
  
  for volume in $@; do
      # look for import.properties file in the volume
	  if [[ -f "$volume/import.properties" ]]; then
		  echo "Importing into JasperReports Server from $volume"
	  
		  # parse import.properties. each uncommented line with contents will have
		  # js-import command line parameters
		  # see "Importing from the Command Line" in JasperReports Server Admin guide
		  
		  while read -r line
		  do
			if [ -z "$line"  -o "${line:0:1}" == "#" ]; then
			  #echo "comment line or blank line"
			  continue
			fi

			# split up the args
			IFS=' ' read -r -a args <<< "$line"
			command=""
			foundInput=false
			element=""
			for index in "${!args[@]}"
			do
				element="${args[index]}"
				if [ "$element" = "--input-dir" -o "$element" = "--input-zip" ]; then
				  # find the --input-dir or --input-zip values
				  #echo "found $element"
				  foundInput=true
				elif [ "$foundInput" = true ]; then
				  #echo "setting $volume/$element"
				  # update input to include the volume
				  element="$volume/$element"
				  foundInput=false
				fi
				command="$command $element"
			done
			
			./js-import.sh "$command"
		  done < "$volume/import.properties"
		  # rename import.properties to stop accidental re-import
	      mv "$volume/import.properties" "$volume/import-done.properties"
      else
		  echo "No import.properties file in $volume. Skipping import."
	  fi
  done
}


export() {
  initialize_deploy_properties
  # Export from the passed in list of volumes
  
  cd /usr/src/jasperreports-server/buildomatic/
  
  for volume in $@; do
      # look for export.properties file in the volume
	  if [[ -f "$volume/export.properties" ]]; then
		  echo "Exporting into JasperReports Server into $volume"
	  
		  # parse export.properties. each uncommented line with contents will have
		  # js-export command line parameters
		  # see "Exporting from the Command Line" in JasperReports Server Admin guide
		  
		  while read -r line
		  do
			if [ -z "$line"  -o "${line:0:1}" == "#" ]; then
			  #echo "comment line or blank line"
			  continue
			fi

			# split up the args
			IFS=' ' read -r -a args <<< "$line"
			command=""
			foundInput=false
			element=""
			for index in "${!args[@]}"
			do
				element="${args[index]}"
				# find the --output-dir or --output-zip values
				if [ "$element" = "--output-dir" -o "$element" = "--output-zip" ]; then
				  #echo "found $element"
				  foundInput=true
				elif [ "$foundInput" = true ]; then
				  # update output name to include the volume
				  element="$volume/$element"
				  foundInput=false
				fi
				command="$command $element"
			done
			
			./js-export.sh "$command"
		  done < "$volume/export.properties"
		  # rename export.properties to stop accidental re-export
	      mv "$volume/export.properties" "$volume/export-done.properties"
      else
		  echo "No export.properties file in $volume. Skipping export."
	  fi
  done
}

  
# echo "JAVA environment variables"
# env | grep JAVA
# echo "JAVA version: " && java -version
# echo "PATH: $PATH"
# echo "whereis java: " && whereis java

initialize_deploy_properties

case "$1" in
  run)
    shift 1
    run_jasperserver "$@"
    ;;
  init)
    shift 1
    init_databases "$@"
    ;;
  import)
    shift 1
    import "$@"
    ;;
  export)
    shift 1
    export "$@"
    ;;
  *)
    exec "$@"
esac

