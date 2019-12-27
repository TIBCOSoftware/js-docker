#!/bin/bash

# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# JasperReports Server command line tools.
# init_databases. creates JRS repository database, and foodmart and sugarcrm if JRS_LOAD_SAMPLES = true
# import: runs js-import based on import.properties file in given volume
# export: runs js-export based on export.properties file in given volume
# Default "init"

# Sets script to fail if any command fails.
set -e

. /common-environment.sh

# tests for JasperReports Server repository, and foodmart and sugarcrm sample databases
# and creates them if needed
init_databases() {
  
  sawAdministrative="notyet"
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
	echo $line
	case "$line" in
		*"Validating"* )
			case "$line" in
				*"administrative"* )
				  currentDatabase=administrative
				  ;;
				*"JasperServer"* )
				  currentDatabase=JasperServer
				  ;;
				*"FoodMart"* )
				  currentDatabase=foodmart
				  ;;
				*"SugarCRM"*  )
				  currentDatabase=sugarcrm
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
			  foodmart )
				sawFoodmartDBName="no"
				;;
			  sugarcrm )
				sawSugarCRMDBName="no"
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
			  foodmart )
				sawFoodmartDBName="yes"
				;;
			  sugarcrm )
				sawSugarCRMDBName="yes"
				;;
			  *)
				echo "Connection OK unknown database"
			esac
			sawConnectionOK=$((sawConnectionOK + 1))
			;;
	esac
  done < <(./js-ant do-pre-install-test)
  
  if [ "$sawConnectionOK" -lt 1 ]; then
	echo "##### Failing! ##### Saw $sawConnectionOK OK connections to $DB_TYPE on host ${DB_HOST}. Expected at least 1."
    return 1
  fi
  
  echo "Database init status: administrative : $sawAdministrative , $DB_NAME : $sawJRSDBName , foodmart: $sawFoodmartDBName , sugarcrm $sawSugarCRMDBName"
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
    echo "$DB_NAME repository database already exists: not creating and loading it or samples"
  fi
}

import() {

    # Import from the passed in list of volumes
	# Default: use import.properties file in the given volume
	# could be passed in /path/to/volume/aProperties.file
	# use that as the volume for files and the named properties file
  
  cd ${BUILDOMATIC_HOME}
  
  for path in $@; do
    importFileName="import.properties"
	volume="$path"

    # custom volume/properties file; not a directory
	if [ ! -d "$path" ]; then
	  importFileName="${path##*/}"
	  volume="${path%/*}"
	fi

    # look for import command file - "import.properties" default - in the given volume

    if [[ ! -e "$volume/$importFileName" ]]; then
      echo "No '$importFileName' file in $volume. Skipping import."
	  continue
    fi

    echo "Importing commands from $importFileName in $volume into JasperReports Server"

    # parse import.properties. each uncommented line with contents will have
    # js-import command line parameters
    # see "Importing from the Command Line" in JasperReports Server Admin guide
	
	# create log output directory on volume
	outputDir="$volume/import-$(date "+%F-%H-%M-%S")"
	mkdir $outputDir
        
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
		  printCommand=""
		  foundInput=false
		  foundSecret=false
		  element=""
		  printElement=""
	  
          for index in "${!args[@]}"
          do
            element="${args[index]}"
			printElement="${args[index]}"
			case "$element" in
			  --input-dir | --input-zip | --keystore )
				foundInput=true
				;;
			  --secret-key | --keypass )
				foundSecret=true
				;;
			  *)
				# assume file args are in the volume,
				# so update the arg with the volume
				if [ "$foundInput" = true ]; then
				  # update file reference to include the volume
				  element="$volume/$element"
				  foundInput=false
				elif [ "$foundSecret" = true ]; then
				  # suppress secrets
				  printElement="********"
				  foundSecret=false
				fi
				;;
			esac
			command="$command $element"
			printCommand="$printCommand $printElement"
          done
			
          thisImportTime=$(date "+%F-%H-%M-%S")
          
          echo "js-import $printCommand" 2>&1 | tee "$outputDir/import-$thisImportTime.log"
          echo "=========================" 2>&1 | tee "$outputDir/import-$thisImportTime.log"

          ./js-import.sh "$command" 2>&1 | tee "$outputDir/import-$thisImportTime.log" || echo "Import $command failed"
      done < "$volume/import.properties"
      # rename import.properties to stop accidental re-import
      mv "$volume/$importFileName" "$outputDir"
  done
}


export() {

    # Export from the passed in list of volumes
	# Default: use export.properties file in the given volume
	# could be passed in /path/to/volume/aProperties.file
	# use that as the volume for files and the named properties file
    
    cd ${BUILDOMATIC_HOME}
	
    for path in $@; do
		exportFileName=export.properties
		volume="$path"

		# custom volume/properties file; not a directory
		if [ -e "$path" ]; then
			exportFileName="${path##*/}"
			volume="${path%/*}"
		fi

		# look for export command file - "export.properties" default - in the given volume

		if [[ ! -f "$volume/$exportFileName" ]]; then
			echo "No '$exportFileName' file in $volume. Skipping import."
			continue
		fi
		
		echo "Exporting commands from $exportFileName into JasperReports Server into $volume"

		# create log output directory on volume
		outputDir="$volume/export-$(date "+%F-%H-%M-%S")"
		mkdir $outputDir

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
			printCommand=""
			foundOutput=false
			foundSecret=false
			element=""
			printElement=""

			for index in "${!args[@]}"
			do
				element="${args[index]}"
				printElement="${args[index]}"
				case "$element" in
				  --output-dir | --output-zip | --destkeystore )
					foundOutput=true
					;;
				  --secret-key | --keypass | --deststorepass | --destkeypass )
					foundSecret=true
					;;
				  *)
					# assume file args are in the volume,
					# so update the arg with the volume
					if [ "$foundOutput" = true ]; then
					  # update file reference to include the outputDir
					  element="$outputDir/$element"
					  foundOutput=false
					fi
					# don't log secrets
					if [ "$foundSecret" = true ]; then
					  # suppress secrets
					  printElement="********"
					  foundSecret=false
					fi
					;;
				esac
				command="$command $element"
				printCommand="$printCommand $printElement"
			done
			
			thisExportTime=$(date "+%F-%H-%M-%S")
			
			echo "js-export $printCommand" 2>&1 | tee "$outputDir/export-$thisExportTime.log"
			echo "=========================" 2>&1 | tee "$outputDir/export-$thisExportTime.log"

			./js-export.sh "$command" 2>&1 | tee "$outputDir/export-$thisExportTime.log" || echo "Export $command failed" | tee "$outputDir/export-$thisExportTime.log"

		done < "$volume/$exportFileName"
		# rename export.properties to stop accidental re-export
		mv "$volume/$exportFileName" "$outputDir"
    done
}


initialize_deploy_properties

# not doing app server management during command line work
  cat >> ${BUILDOMATIC_HOME}/default_master.properties\
<<-_EOL_
appServerType=skipAppServerCheck
_EOL_

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

