#!/bin/bash

set -u

DEBUG=false

PROJ_ROOT_PATH=$(cd "${0%/*}" && echo $PWD)
REPO_ROOT_PATH=$(cd "$PROJ_ROOT_PATH/../" && echo $PWD)
DOCKER_PATH="$REPO_ROOT_PATH/jaspersoft-containers/Docker"
K8S_PATH="$REPO_ROOT_PATH/jaspersoft-containers/K8s"

INSTALLER_ZIP=TIB_js-jrs_8.1.0_bin.zip
INSTALLER_PATH="$REPO_ROOT_PATH/jasperreports-server-pro-8.1.0-bin"

BUILD=true

delete_quietly() {
  [ -e $1 ] && rm $1
}

while getopts ":d:b:" opt; do
  case $opt in
    d)
      DEBUG=true >&2
      ;;
    b)
      BUILD=$OPTARG >&2
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

# Update Docker default master properties file with customized version
cp $PROJ_ROOT_PATH/docker.default_master.properties $DOCKER_PATH/jrs/resources/default-properties/default_master.properties

# Update Docker Compose environment file with customized version
cp $PROJ_ROOT_PATH/docker.env $DOCKER_PATH/jrs/.env

# Unzip JasperReport Server installer archive
#   -o  Overwrite without prompting
#   -q  Quietly unless debug is true
#   -d  Unzip to repository root directory
unzip -o $($DEBUG && echo "" || echo "-q") $INSTALLER_ZIP -d $REPO_ROOT_PATH

# Delete existing Buildomatic default master properties file
delete_quietly $INSTALLER_PATH/buildomatic/default_master.properties

# Delete existing keystore files in user home and Docker keystore directories
delete_quietly ~/.jrsks
delete_quietly ~/.jrsksp
delete_quietly $DOCKER_PATH/jrs/resources/keystore/.jrsks
delete_quietly $DOCKER_PATH/jrs/resources/keystore/.jrsksp

# Update Buildomatic keystore creation default master properties file with customized PostgreSQL version
cp $PROJ_ROOT_PATH/keystore.postgres.default_master.properties $INSTALLER_PATH/buildomatic/default_master.properties

# Generate keystore files
cd $INSTALLER_PATH/buildomatic
source ./js-ant gen-config <<<$'y'
cp ~/.jrsks $DOCKER_PATH/jrs/resources/keystore
cp ~/.jrsksp $DOCKER_PATH/jrs/resources/keystore
chmod 644 $DOCKER_PATH/jrs/resources/keystore/.jrsks
chmod 644 $DOCKER_PATH/jrs/resources/keystore/.jrsksp

# Build Docker images using Docker Compose
$BUILD && docker-compose -f $DOCKER_PATH/jrs/docker-compose.yml build

# Delete keystore files created in user home directory
delete_quietly ~/.jrsks
delete_quietly ~/.jrsksp