#!/bin/bash

set -u

FORCE=true

PROJ_ROOT_PATH=$(cd "${0%/*}" && echo "$PWD")
PROJ_CONF_PATH=$(cd "$PROJ_ROOT_PATH/conf" && echo "$PWD")
REPO_ROOT_PATH=$(cd "$PROJ_ROOT_PATH/../" && echo "$PWD")
DOCKER_PATH="$REPO_ROOT_PATH/jaspersoft-containers/Docker"
K8S_PATH="$REPO_ROOT_PATH/jaspersoft-containers/K8s"

INSTALLER_ZIP="TIB_js-jrs_8.1.0_bin.zip"
INSTALLER_PATH="$REPO_ROOT_PATH/jasperreports-server-pro-8.1.0-bin"

K8S_NAMESPACE="jasper-reports"
K8S_POSTGRES_POD_NAME="pod/repository-postgresql-0"

msg() {
  printf "\n🦄 %s\n\n" "$1"
}

msg_ol() {
  printf "\n🦄 %s\n" "$1"
}

delete_quietly() {
  [ -e "$1" ] && rm "$1"
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
  delete_quietly "$DOCKER_PATH/jrs/resources/keystore/.jrsks"
  delete_quietly "$DOCKER_PATH/jrs/resources/keystore/.jrsksp"
  # Checkout existing Docker Componse environment file
  git checkout "$DOCKER_PATH/jrs/.env"
  # Checkout original Docker default master peroperties file
  git checkout "$DOCKER_PATH/jrs/resources/default-properties/default_master.properties"
  # Delete existing keystore files in Helm keystore directory
  delete_quietly "$K8S_PATH/jrs/helm/secrets/keystore/.jrsks"
  delete_quietly "$K8S_PATH/jrs/helm/secrets/keystore/.jrsksp"
  # Delete existing Buildomatic default master properties file
  delete_quietly "$INSTALLER_PATH/buildomatic/default_master.properties"
  # Delete existing license file in Helm license directory
  delete_quietly "$K8S_PATH/jrs/helm/secrets/license/jasperserver.license"
  # Checkout original Helm chart lock file
  git checkout jaspersoft-containers/K8s/jrs/helm/Chart.lock >&1
}

while getopts ":cfn:" opt; do
  case $opt in
    c)
      clean
      echo
      exit
      ;;  
    f)
      FORCE=true
      ;;
    n)
      K8S_NAMESPACE=$OPTARG
      ;;    
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

msg "Running with the following parameters"

echo "   FORCE=${FORCE}"
echo "   REPO_ROOT_PATH=${REPO_ROOT_PATH}"
echo "   PROJ_ROOT_PATH=${PROJ_ROOT_PATH}"
echo "   PROJ_CONF_PATH=${PROJ_CONF_PATH}"
echo "   DOCKER_PATH=${DOCKER_PATH}"
echo "   K8S_PATH=${K8S_PATH}"
echo "   INSTALLER_ZIP=${INSTALLER_ZIP}"
echo "   INSTALLER_PATH=${INSTALLER_PATH}"
echo "   K8S_NAMESPACE=${K8S_NAMESPACE}"
echo "   K8S_POSTGRES_POD_NAME=${K8S_POSTGRES_POD_NAME}"

clean

#
# Installer
#

msg_ol "Unzipping JasperReports Server installation archive to repository root"

# Unzip JasperReports Server installer archive
#   -o  Overwrite without prompting
#   -q  Quietly
#   -d  To repo root directory
unzip -o -q "$INSTALLER_ZIP" -d "$REPO_ROOT_PATH"

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
kubectl create namespace "$K8S_NAMESPACE"
kubectl config set-context --current --namespace="$K8S_NAMESPACE"

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
cp "$PROJ_CONF_PATH/docker.env" "$DOCKER_PATH/jrs/.env"

# Update Docker default master properties file with customized version
cp "$PROJ_CONF_PATH/docker.default_master.properties" "$DOCKER_PATH/jrs/resources/default-properties/default_master.properties"
sed -i '' "s/K8S_NAMESPACE/$K8S_NAMESPACE/g" "$DOCKER_PATH/jrs/resources/default-properties/default_master.properties"

# Build Docker images using Docker Compose
# TODO: Remove --no-cache flag
docker-compose -f "$DOCKER_PATH/jrs/docker-compose.yml" build --no-cache

#
# Keystore
#

msg "Generating keystore files"

# Update Buildomatic keystore creation default master properties file with customized PostgreSQL version
cp "$PROJ_CONF_PATH/keystore.postgres.default_master.properties" "$INSTALLER_PATH/buildomatic/default_master.properties"

# Generate keystore files
cd "$INSTALLER_PATH/buildomatic" || exit
# shellcheck disable=SC1091
source ./js-ant gen-config <<<$'y'

msg_ol "Copying generated keystore files to Docker keystore directory"

# Copy the generated keystore files to the Docker keystore directory with 644 permissions
cp ~/.jrsks "$DOCKER_PATH/jrs/resources/keystore"
cp ~/.jrsksp "$DOCKER_PATH/jrs/resources/keystore"
chmod 644 "$DOCKER_PATH/jrs/resources/keystore/.jrsks"
chmod 644 "$DOCKER_PATH/jrs/resources/keystore/.jrsksp"

#
# Helm
# 

msg_ol "Copying JasperReports Server license file to Helm license directory"

# Copy license file to Helm license directory
cp "$PROJ_CONF_PATH/jasperserver.license" "$K8S_PATH/jrs/helm/secrets/license"

msg_ol "Copying generated keystore files to Helm keystore directory"

# Copy the generated keystore files to the Helm keystore directory with 644 permissions
cp ~/.jrsks "$K8S_PATH/jrs/helm/secrets/keystore"
cp ~/.jrsksp "$K8S_PATH/jrs/helm/secrets/keystore"
chmod 644 "$K8S_PATH/jrs/helm/secrets/keystore/.jrsks"
chmod 644 "$K8S_PATH/jrs/helm/secrets/keystore/.jrsksp"

msg "Adding and updating Helm chart dependencies"

# Add Helm dependency chart repositories and update Helm dependencies
cd "$K8S_PATH" || exit
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add haproxytech https://haproxytech.github.io/helm-charts
helm repo add elastic https://helm.elastic.co
helm dependencies update jrs/helm

# Install PostgreSQL chart into the correct namespace
helm install repository bitnami/postgresql --set auth.postgresPassword=postgres --namespace $K8S_NAMESPACE

# Wait for the PostgreSQL pod to be ready
printf "\n🦄 Giving the PostgreSQL pod a few seconds to warm up ... (5s) "
for i in {5..1};
do
  printf "\b\b\b\b%ss) " "$i"
  sleep 1
done
printf "\b\b\b\b🔥) \n"

msg "A single PostgreSQL pod named '$K8S_POSTGRES_POD_NAME' should be coming up in the '$K8S_NAMESPACE' namespace"

kubectl get pods -n "$K8S_NAMESPACE"

printf "\n🦄 Waiting for the PostgreSQL pod to have the Running status ... (/) "

# shellcheck disable=SC1003
while [[ $(kubectl get $K8S_POSTGRES_POD_NAME -n $K8S_NAMESPACE -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; 
do for X in '-' '\' '|' '/'; do printf "\b\b\b%s) " "$X"; sleep 0.1; done; done 
printf "\b\b\b\b(👍) \n"

msg "Current K8s pods in the '$K8S_NAMESPACE' namespace"

kubectl get pods -n "$K8S_NAMESPACE"

msg "Installing JasperReports Server Helm charts"

# shellcheck disable=SC2028
echo "------------------------------------------------

Verification:

  A pod named 'pod/jasperserver-buildomatic-<id>' will start in the '$K8S_NAMESPACE' namespace  with the
  purpose of setting up the JRS repository DB.

  To connect to the repository DB at any time the '$K8S_POSTGRES_POD_NAME' is running:

    $ kubectl port-forward --namespace $K8S_NAMESPACE svc/repository-postgresql 5432:5432

  Once completed successfully the buildomatic pod will be destroyed.

  Three additional pods will start in the '$K8S_NAMESPACE' namespace with the names:

    pod/jasperserver-cache-<id>
    pod/jrs-jasperserver-ingress-<id>
    pod/jrs-jasperserver-pro-<id>

  To watch the JRS webapp logs during startup:

    $ kubectl logs --follow pod/jrs-jasperserver-pro-<id>

  Once the pod named 'pod/jrs-jasperserver-ingress-<id>' is in the Ready state, you'll need to forward
  http traffic from your localhost to the JRS service to be able to view the JRS UI in a browser.

    $ kubectl port-forward --namespace $K8S_NAMESPACE service/jrs-jasperserver-ingress 8080:80

  Open http://127.0.0.1:8080/jasperserver-pro/login.html in a browser to verify the server is up and running.

Troubleshooting:

  It's important that the pod named 'pod/jasperserver-cache-<id>' is Ready before the webapp pod comes up,
  however often it doesn't. When the cache pod is not ready for the webapp, you'll see errors in the webapp 
  logs similar to:
  
  Could not connect to broker URL: tcp://jasperserver-cache-service.$K8S_NAMESPACE.svc.cluster.local:61616

  When this occurs: Delete the webapp pod and let the deployment recreate it OR just be patient and the 
  webapp pod will be restarted and should come up without error.

You may kill this terminal once the K8S deployments have been created.

(╯°□°）╯︵ puƎ ǝɥꓕ
------------------------------------------------
"

# Install JasperReports Server charts into specified namespace
helm install jrs jrs/helm --namespace "$K8S_NAMESPACE" --wait --timeout 6m0s --set buildomatic.includeSamples=false
