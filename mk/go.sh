#!/bin/bash

set -u

FORCE=true

PROJ_ROOT_PATH=$(cd "${0%/*}" && echo $PWD)
REPO_ROOT_PATH=$(cd "$PROJ_ROOT_PATH/../" && echo $PWD)
DOCKER_PATH="$REPO_ROOT_PATH/jaspersoft-containers/Docker"
K8S_PATH="$REPO_ROOT_PATH/jaspersoft-containers/K8s"

INSTALLER_ZIP=TIB_js-jrs_8.1.0_bin.zip
INSTALLER_PATH="$REPO_ROOT_PATH/jasperreports-server-pro-8.1.0-bin"

K8S_NAMESPACE=jasper-reports
K8S_POSTGRES_POD_NAME="pod/repository-postgresql-0"

msg() {
  printf "\n🦄 %s\n\n" "$1"
}

msg_ol() {
  printf "\n🦄 %s\n" "$1"
}

delete_quietly() {
  [ -e $1 ] && rm $1
}

#
# Clean
#

clean() {
  msg "Cleaning generated and modified files"

  # Delete existing keystore files in user home
  delete_quietly ~/.jrsks
  delete_quietly ~/.jrsksp
  # Delete existing keystore files in Docker keystore directory
  delete_quietly $DOCKER_PATH/jrs/resources/keystore/.jrsks
  delete_quietly $DOCKER_PATH/jrs/resources/keystore/.jrsksp
  # Checkout existing Docker Componse environment file
  git checkout $DOCKER_PATH/jrs/.env
  # Checkout original Docker default master peroperties file
  git checkout $DOCKER_PATH/jrs/resources/default-properties/default_master.properties
  # Delete existing keystore files in Helm keystore directory
  delete_quietly $K8S_PATH/jrs/helm/secrets/keystore/.jrsks
  delete_quietly $K8S_PATH/jrs/helm/secrets/keystore/.jrsksp
  # Delete existing Buildomatic default master properties file
  delete_quietly $INSTALLER_PATH/buildomatic/default_master.properties
  # Delete existing license file in Helm license directory
  delete_quietly $K8S_PATH/jrs/helm/secrets/license/jasperserver.license
  # Checkout original Helm chart lock file
  git checkout jaspersoft-containers/K8s/jrs/helm/Chart.lock >&1
}

while getopts ":cf" opt; do
  case $opt in
    c)
      clean
      echo
      exit
      ;;  
    b)
      FORCE=true
      ;;    
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

msg "Running with the following parameters"

echo "   PROJ_ROOT_PATH=${PROJ_ROOT_PATH}"
echo "   REPO_ROOT_PATH=${REPO_ROOT_PATH}"
echo "   DOCKER_PATH=${DOCKER_PATH}"
echo "   K8S_PATH=${K8S_PATH}"
echo "   INSTALLER_ZIP=${INSTALLER_ZIP}"
echo "   INSTALLER_PATH=${INSTALLER_PATH}"

clean

#
# Installer
#

msg_ol "Unzipping JasperReports Server installation archive to repository root"

# Unzip JasperReports Server installer archive
#   -o  Overwrite without prompting
#   -q  Quietly
#   -d  Unzip to repository root directory
unzip -o -q $INSTALLER_ZIP -d $REPO_ROOT_PATH

#
# Minikube
#

# Confirm minikube delete
if ! $FORCE; then
  read -p $'\n'"💀 Warning! This will run minikube delete, continue? <y/N> " -r prompt
  if [[ $prompt != "y" && $prompt != "Y" && $prompt != "yes" && $prompt != "Yes" ]]; then
    exit 1
  fi
fi

msg "Deleting minikube cluster"
minikube delete

msg "Starting minikube cluster"
minikube start

msg "Creating K8S namespace '$K8S_NAMESPACE' in minikube"
kubectl config use-context minikube
kubectl create namespace $K8S_NAMESPACE
kubectl config set-context --current --namespace=$K8S_NAMESPACE

msg "Current K8S contexts:"
kubectl config get-contexts

# Connect Docker CLI to minikube Docker daemon
msg_ol "Connecting Docker CLI to minikube Docker daemon"
eval "$(minikube -p minikube docker-env)" 

#
# Docker Images
#

msg "Building JasperReports Server Docker images using Docker Compose"

# Update Docker Compose environment file with customized version
cp $PROJ_ROOT_PATH/docker.env $DOCKER_PATH/jrs/.env

# Update Docker default master properties file with customized version
cp $PROJ_ROOT_PATH/docker.default_master.properties $DOCKER_PATH/jrs/resources/default-properties/default_master.properties

# Build Docker images using Docker Compose
# TODO: Remove --no-cache flag
docker-compose -f $DOCKER_PATH/jrs/docker-compose.yml build --no-cache

#
# Keystore
#

msg "Generating keystore files"

# Update Buildomatic keystore creation default master properties file with customized PostgreSQL version
cp $PROJ_ROOT_PATH/keystore.postgres.default_master.properties $INSTALLER_PATH/buildomatic/default_master.properties

# Generate keystore files
cd $INSTALLER_PATH/buildomatic
source ./js-ant gen-config <<<$'y'

msg_ol "Copying generated keystore files to Docker keystore directory"

# Copy the generated keystore files to the Docker keystore directory with 644 permissions
cp ~/.jrsks $DOCKER_PATH/jrs/resources/keystore
cp ~/.jrsksp $DOCKER_PATH/jrs/resources/keystore
chmod 644 $DOCKER_PATH/jrs/resources/keystore/.jrsks
chmod 644 $DOCKER_PATH/jrs/resources/keystore/.jrsksp

#
# Helm
# 

msg_ol "Copying JasperReports Server license file to Helm license directory"

# Copy license file to Helm license directory
cp $PROJ_ROOT_PATH/jasperserver.license $K8S_PATH/jrs/helm/secrets/license

msg_ol "Copying generated keystore files to Helm keystore directory"

# Copy the generated keystore files to the Helm keystore directory with 644 permissions
cp ~/.jrsks $K8S_PATH/jrs/helm/secrets/keystore
cp ~/.jrsksp $K8S_PATH/jrs/helm/secrets/keystore
chmod 644 $K8S_PATH/jrs/helm/secrets/keystore/.jrsks
chmod 644 $K8S_PATH/jrs/helm/secrets/keystore/.jrsksp

msg "Adding and updating Helm chart dependencies"

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
printf "\n🦄 Giving the PostgreSQL pod a few seconds to warm up ... (5s) "
for i in {5..1};
do
  printf "\b\b\b\b%ss) " "$i"
  sleep 1
done
printf "\b\b\b\b🔥) \n"

msg "A single PostgreSQL pod named '$K8S_POSTGRES_POD_NAME' should be coming up in the default namespace"

kubectl get pods -n default

printf "\n🦄 Waiting for the PostgreSQL pod to have the Running status ... (/) "

while [[ $(kubectl get $K8S_POSTGRES_POD_NAME -n default -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; 
do for X in '-' '\' '|' '/'; do printf "\b\b\b%s) " "$X"; sleep 0.1; done; done 
printf "\b\b\b\b(👍) \n"

msg "Current K8s pods in the 'default' namespace"

kubectl get pods -n default

msg "Installing JasperReports Server Helm charts"

# TODO: Additional information and troubleshooting

# Install JasperReports Server charts into specified namespace
helm install jrs jrs/helm --namespace $K8S_NAMESPACE --wait --timeout 12m0s --set buildomatic.includeSamples=false

# kubectl port-forward --namespace jasper-reports service/jrs-jasperserver-ingress 8080:80
# http://127.0.0.1:8080/jasperserver-pro/login.html

# Could not connect to broker URL: tcp://jasperserver-cache-service.jasper-reports.svc.cluster.local:61616