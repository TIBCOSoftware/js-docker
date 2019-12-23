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

. /common-environment.sh

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
  
  cd ${BUILDOMATIC_HOME}/
  
  while read -r line
  do
	if [ -z "$line" ]; then
	  #echo "blank line"
	  continue
	fi
	if [[ $line == *"$DB_NAME"* ]]; then
	  currentDatabase=$DB_NAME
	elif [[ $line == *"foodmart"* ]]; then
	  currentDatabase=foodmart
	elif [[ $line == *"sugarcrm"* ]]; then
	  currentDatabase=sugarcrm
	elif [[ $line == *"Database doesn"* ]]; then
		case "$currentDatabase" in
		  $DB_NAME )
			sawJRSDBName="no"
			;;
		  foodmart )
			sawFoodmartDBName="no"
			;;
		  sugarcrm )
			sawSugarCRMDBName="no"
			;;
		  *)
		esac
	elif [[ $line == *"Connection OK"* ]]; then
		case "$currentDatabase" in
		  $DB_NAME )
			sawJRSDBName="yes"
			;;
		  foodmart )
			sawFoodmartDBName="yes"
			;;
		  sugarcrm )
			sawSugarCRMDBName="yes"
			;;
		  *)
		esac
	    sawConnectionOK=$((sawConnectionOK + 1))
	fi
  done < <(./js-ant do-pre-install-test)
  
  if [ "$sawConnectionOK" -lt 1 ]; then
	echo "##### Exiting! ##### saw no OK connections"
    exit 1
  fi
  
  echo "Database init status: $DB_NAME : $sawJRSDBName foodmart: $sawFoodmartDBName  sugarcrm $sawSugarCRMDBName"
  if [ "$sawJRSDBName" = "no" ]; then
    echo "Initializing $DB_NAME repository database"
	execute_buildomatic set-pro-webapp-name create-js-db init-js-db-pro import-minimal-pro
	
	JRS_LOAD_SAMPLES=${JRS_LOAD_SAMPLES:-false}
	  
	# Only install the samples if explicitly requested
	if [ "$1" = "samples" -o "$JRS_LOAD_SAMPLES" = "true" ]; then
		echo "Samples load requested"
		# if foodmart database not present - setup database
		if [ "$sawFoodmartDBName" = "no" ]; then
			execute_buildomatic create-foodmart-db \
							load-foodmart-db \
							update-foodmart-db
		fi

		# if sugarcrm database not present - setup database
		if [ "$sawSugarCRMDBName" = "no" ]; then
			execute_buildomatic create-sugarcrm-db \
							load-sugarcrm-db 
		fi

		execute_buildomatic import-sample-data-pro
	fi
  else
    echo "$DB_NAME repository database already exists: not creating and loading"
  fi
}

import() {

  # not doing app server management during an import
  cat >> ${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
appServerType=skipAppServerCheck
_EOL_

  # Import from the passed in list of volumes
  
  cd ${BUILDOMATIC_HOME}
  
  for volume in $@; do
      # look for import.properties file in the volume
      if [[ -f "$volume/import.properties" ]]; then
        echo "Importing into JasperReports Server from $volume"
      
        # parse import.properties. each uncommented line with contents will have
        # js-import command line parameters
        # see "Importing from the Command Line" in JasperReports Server Admin guide
          
        while read -r line
        do
          line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

          if [ -z "$line" -o "${line:0:1}" == "#" ]; then
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
            
            echo "Import $command executing"
            echo "========================="

            ./js-import.sh "$command" || echo "Import $command failed"
        done < "$volume/import.properties"
        # rename import.properties to stop accidental re-import
        mv "$volume/import.properties" "$volume/import-done.properties"
      else
        echo "No import.properties file in $volume. Skipping import."
      fi
  done
}


export() {

    # not doing app server management during an export
    cat >> ${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
appServerType=skipAppServerCheck
_EOL_

    # Export from the passed in list of volumes
    
    cd ${BUILDOMATIC_HOME}
    
    for volume in $@; do
        # look for export.properties file in the volume
        if [[ -f "$volume/export.properties" ]]; then
            echo "Exporting into JasperReports Server into $volume"
        
            # parse export.properties. each uncommented line with contents will have
            # js-export command line parameters
            # see "Exporting from the Command Line" in JasperReports Server Admin guide
            
            while read -r line
            do
                line="$(echo -e "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

                if [ -z "$line" -o "${line:0:1}" == "#" ]; then
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
            
                echo "Export $command executing"
                echo "========================="

                ./js-export.sh "$command" || echo "Export $command failed"

            done < "$volume/export.properties"
            # rename export.properties to stop accidental re-export
            mv "$volume/export.properties" "$volume/export-done.properties"
        else
            echo "No export.properties file in $volume. Skipping export."
        fi
    done
}


initialize_deploy_properties

case "$1" in
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

