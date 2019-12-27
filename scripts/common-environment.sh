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

# make buildomatic not ask interactive questions
export BUILDOMATIC_MODE=script

BUILDOMATIC_HOME=${BUILDOMATIC_HOME:-/usr/src/jasperreports-server/buildomatic}
MOUNTS_HOME=${MOUNTS_HOME:-/usr/local/share/jasperserver-pro}

KEYSTORE_PATH=${KEYSTORE_PATH:-${MOUNTS_HOME}/keystore}
export ks=$KEYSTORE_PATH
export ksp=$KEYSTORE_PATH

initialize_deploy_properties() {
  # If environment is not set, uses default values for postgres
  DB_TYPE=${DB_TYPE:-postgresql}
  DB_USER=${DB_USER:-postgres}
  DB_PASSWORD=${DB_PASSWORD:-postgres}
  DB_HOST=${DB_HOST:-postgres}
  DB_NAME=${DB_NAME:-jasperserver}
  ks=${KEYSTORE_PATH}
  ksp=${KEYSTORE_PATH}

  echo "Current keystore files in $KEYSTORE_PATH"
  # echo $JRSKS_PATH_FILES

  if [ ! -f "$KEYSTORE_PATH/.jrsks" -o ! -f "$KEYSTORE_PATH/.jrsksp" ]; then
	  echo ".jrsks missing in $KEYSTORE_PATH. They will be created"
  fi

  # Default_master.properties. Modify according to
  # JasperReports Server documentation.
  cat >${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
appServerType=tomcat
appServerDir=$CATALINA_HOME
dbType=$DB_TYPE
dbHost=$DB_HOST
dbUsername=$DB_USER
dbPassword=$DB_PASSWORD
js.dbName=$DB_NAME
foodmart.dbName=foodmart
sugarcrm.dbName=sugarcrm
webAppName=jasperserver-pro
ks=$KEYSTORE_PATH
ksp=$KEYSTORE_PATH
_EOL_

  # set the JDBC_DRIVER_VERSION if it is passed in.
  # Otherwise rely on the default maven.jdbc.version from the dbType
  if [ ! -z "$JDBC_DRIVER_VERSION" ]; then
    cat >> ${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
maven.jdbc.version=$JDBC_DRIVER_VERSION
_EOL_
  elif [ "$DB_TYPE" = "postgresql" ]; then
    POSTGRES_JDBC_DRIVER_VERSION=${POSTGRES_JDBC_DRIVER_VERSION:-42.2.5}
    cat >> ${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
maven.jdbc.version=$POSTGRES_JDBC_DRIVER_VERSION
_EOL_
  fi

  # set the DB_PORT if it is passed in.
  # Otherwise rely on the default port from the dbType
  if [ ! -z "$DB_PORT" ]; then
    cat >> ${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
dbPort=$DB_PORT
_EOL_
  fi
  
  JRS_DEPLOY_CUSTOMIZATION=${JRS_DEPLOY_CUSTOMIZATION:-${MOUNTS_HOME}/deploy-customization}

  if [[ -f "$JRS_DEPLOY_CUSTOMIZATION/default_master_additional.properties" ]]; then
    # note that because these properties are at the end of the properties file
	# they will have precedence over the ones created above
    cat $JRS_DEPLOY_CUSTOMIZATION/default_master_additional.properties >> ${BUILDOMATIC_HOME}/default_master.properties
  fi
  
}

test_database_result=nothing

# tests connection to the configured repo database.
# could fail altogether, be missing the database or succeed
# do-install-upgrade-test does 2 connections
# - database specific admin database
# - js.dbName
# at least one attempt has to work to indicate the host is accessible

try_database_connection() {
  local sawAdministrative=notyet
  local sawJRSDBName=notyet
  local sawConnectionOK=0
  local currentDatabase=
      
  cd ${BUILDOMATIC_HOME}/

  while read -r line
  do
	if [ -z "$line" ]; then
	  #echo "blank line"
	  continue
	fi
    echo "$line"
	case "$line" in
		*"Validating"* )
			case "$line" in
				*"administrative"* )
				  currentDatabase=administrative
				  ;;
				*"JasperServer"* )
				  currentDatabase=JasperServer
				  ;;
				*)
				  echo "Validating unknown database"
			esac
			;;
		*"Database doesn"* )
			case "$currentDatabase" in
			  administrative )
				sawAdministrative="no"
				;;
			  JasperServer )
				sawJRSDBName="no"
				;;
			  *)
				echo "database doesn't exist for unknown database"
			esac
			;;
		*"Connection OK"* )
			case "$currentDatabase" in
			  administrative )
				sawAdministrative="yes"
				;;
			  JasperServer )
				sawJRSDBName="yes"
				;;
			  *)
				echo "Connection OK unknown database"
			esac
			sawConnectionOK=$((sawConnectionOK + 1))
			;;
		*"FATAL: database \"$DB_NAME\" does not exist"* )
			sawJRSDBName=fatal
			;;
	esac
	#if [[ $line == *"FATAL: database \"$DB_NAME\" does not exist"* ]]; then
	  
    #elif [[ $sawJRSDBName != "fatal" && $line == *"$DB_NAME"* ]]; then
	#  sawJRSDBName=true
	#fi
	
	# if [[ $line == *"Connection OK"* ]]; then
	  # sawConnectionOK=$((sawConnectionOK + 1))
	# fi
  done < <(./js-ant do-install-upgrade-test)

  if [ "$sawConnectionOK" -lt 2 ]; then
	echo "##### Failing! ##### Saw $sawConnectionOK OK connections, not at least 2."
    test_database_result="fail"
  elif [ "$sawJRSDBName" = "fatal" ]; then
	echo "Repository $DB_NAME of $DB_TYPE on host ${DB_HOST} missing."
    test_database_result="missing"
  else
	echo "Repository $DB_NAME of $DB_TYPE on host ${DB_HOST} available."
	test_database_result="OK"
  fi
}

test_database_connection() {
	# Retry 5 times to check database is accessible.
	for retry in {1..5}; do
	  try_database_connection
	  echo "test_connection returned $test_database_result"
	  if [ "$test_database_result" = "OK" -o "$test_database_result" = "missing" ]; then
		break
	  elif [[ $retry = 5 ]]; then
		echo "Unable to get connection to $DB_TYPE at host ${DB_HOST} after 5 tries."
		echo "##### Exiting #####"
		exit 1
	  else
		echo "Sleeping to try repository $DB_NAME of $DB_TYPE at host ${DB_HOST} connection again..." && sleep 15
	  fi
	done
}

execute_buildomatic() {

  # execute buildomatic js-ant targets for installing/configuring
  # JasperReports Server.
  
  cd ${BUILDOMATIC_HOME}/
  
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

