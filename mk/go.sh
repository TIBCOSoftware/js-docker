#!/bin/bash

set -u

DEBUG=false
BUILD=true

PROJ_ROOT_PATH=$(cd "${0%/*}" && echo $PWD)
REPO_ROOT_PATH=$(cd "$PROJ_ROOT_PATH/../" && echo $PWD)
DOCKER_PATH="$REPO_ROOT_PATH/jaspersoft-containers/Docker"
K8S_PATH="$REPO_ROOT_PATH/jaspersoft-containers/K8s"

INSTALLER_ZIP=TIB_js-jrs_8.1.0_bin.zip
INSTALLER_PATH="$REPO_ROOT_PATH/jasperreports-server-pro-8.1.0-bin"

K8S_NAMESPACE=jasper-reports
K8S_POSTGRES_POD_NAME="pod/repository-postgresql-0"

msg() {
  printf "\n🦄 %s\n" "$1" >&2;
}

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
# Delete existing keystore files in user home, Docker, and Helm keystore directories
delete_quietly ~/.jrsks
delete_quietly ~/.jrsksp
delete_quietly $DOCKER_PATH/jrs/resources/keystore/.jrsks
delete_quietly $DOCKER_PATH/jrs/resources/keystore/.jrsksp
delete_quietly $K8S_PATH/jrs/helm/secrets/keystore/.jrsks
delete_quietly $K8S_PATH/jrs/helm/secrets/keystore/.jrsksp
# Delete existing license file in Helm license directory
delete_quietly $K8S_PATH/jrs/helm/secrets/license/jasperserver.license

# Update Buildomatic keystore creation default master properties file with customized PostgreSQL version
cp $PROJ_ROOT_PATH/keystore.postgres.default_master.properties $INSTALLER_PATH/buildomatic/default_master.properties

# Generate keystore files
cd $INSTALLER_PATH/buildomatic
source ./js-ant gen-config <<<$'y'

# Copy the keystore files to the Docker keystore directory with 644 permissions
cp ~/.jrsks $DOCKER_PATH/jrs/resources/keystore
cp ~/.jrsksp $DOCKER_PATH/jrs/resources/keystore
chmod 644 $DOCKER_PATH/jrs/resources/keystore/.jrsks
chmod 644 $DOCKER_PATH/jrs/resources/keystore/.jrsksp

# Copy the same keystore files to the Helm keystore directory
cp $DOCKER_PATH/jrs/resources/keystore/.jrsks $K8S_PATH/jrs/helm/secrets/keystore
cp $DOCKER_PATH/jrs/resources/keystore/.jrsksp $K8S_PATH/jrs/helm/secrets/keystore

# Delete keystore files created in user home directory
delete_quietly ~/.jrsks
delete_quietly ~/.jrsksp

# Copy license file to Helm license directory
cp $PROJ_ROOT_PATH/jasperserver.license $K8S_PATH/jrs/helm/secrets/license

# Confirm minikube delete
read -p $'\n'"💀 Warning! This will run minikube delete, continue? <y/N> " -r prompt
if [[ $prompt != "y" && $prompt != "Y" && $prompt != "yes" && $prompt != "Yes" ]]; then
  exit 1
fi

# Setup minikub
minikube delete
minikube start
kubectl config use-context minikube
kubectl create namespace $K8S_NAMESPACE
kubectl config set-context --current --namespace=$K8S_NAMESPACE
kubectl config get-contexts

# Connect Docker CLI to minikube Docker daemon
eval "$(minikube -p minikube docker-env)" 

# Build Docker images using Docker Compose
$BUILD && docker-compose -f $DOCKER_PATH/jrs/docker-compose.yml build

# Add Helm dependency chart repositories and update Helm dependencies
cd $K8S_PATH
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add haproxytech https://haproxytech.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm dependencies update jrs/helm

# Install PostgreSQL chart into default namespace
helm install repository bitnami/postgresql --set auth.postgresPassword=postgres --namespace default

# Wait for the PostgreSQL pod to be ready
printf "\n🦄 Giving the pod a few seconds to warm up .. (5s) "
for i in {5..1};
do
  printf "\b\b\b\b%ss) " "$i"
  sleep 1
done
printf "\b\b\b\b0s) \n"

kubectl get pods -n default

msg "A single PostgreSQL pod named '$K8S_POSTGRES_POD_NAME' should be coming up in the default namespace"

printf "\n🦄 Waiting for the PostgreSQL pod to have the Running status ... /"
while [[ $(kubectl get $K8S_POSTGRES_POD_NAME -n default -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; 
do for X in '-' '\' '|' '/'; do printf "\b\b%s " "$X"; sleep 0.1; done; done 
echo

kubectl get pods -n default

# Install JasperReports Server charts into specified namespace
helm install jrs jrs/helm --namespace $K8S_NAMESPACE --wait --timeout 12m0s --set buildomatic.includeSamples=false
