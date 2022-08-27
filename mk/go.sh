#!/bin/bash

set -u

DEBUG=false

PROJ_ROOT_PATH=$(cd "${0%/*}" && echo $PWD)
REPO_ROOT_PATH=$(cd "$PROJ_ROOT_PATH/../" && echo $PWD)
DOCKER_PATH="$REPO_ROOT_PATH/jaspersoft-containers/Docker"
K8S_PATH="$REPO_ROOT_PATH/jaspersoft-containers/K8s"

INSTALLER_ZIP=TIB_js-jrs_8.1.0_bin.zip
INSTALLER_PATH="$REPO_ROOT_PATH/jasperreports-server-pro-8.1.0-bin"

while getopts ":d" opt; do
  case $opt in
    d)
      DEBUG=true >&2
      ;;     
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

$DEBUG && echo
$DEBUG && echo "PROJ_ROOT_PATH=${PROJ_ROOT_PATH}"
$DEBUG && echo "REPO_ROOT_PATH=${REPO_ROOT_PATH}"
$DEBUG && echo "DOCKER_PATH=${DOCKER_PATH}"
$DEBUG && echo "K8S_PATH=${K8S_PATH}"
$DEBUG && echo "INSTALLER_ZIP=${INSTALLER_ZIP}"
$DEBUG && echo "INSTALLER_PATH=${INSTALLER_PATH}"
$DEBUG && echo

# Update docker default master properties file with customized version
cp $PROJ_ROOT_PATH/docker.default_master.properties $DOCKER_PATH/jrs/resources/default-properties/default_master.properties

# Unpack jasper report server installer 
#   -o  Overwrite without prompting
#   -q  Quietly unless debug is true
#   -d  Unzip to repository root directory
unzip -o $($DEBUG && echo "" || echo "-q") $INSTALLER_ZIP -d $REPO_ROOT_PATH
