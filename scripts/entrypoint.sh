#!/bin/bash

# Copyright (c) 2019. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# This script sets up and runs JasperReports Server on container start.
# Default "run" command, set in Dockerfile, executes run_jasperserver.
# Use jasperserver-pro-cmdline to initialize the repository database

# Sets script to fail if any command fails.
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. $DIR/common-environment.sh

run_jasperserver() {

  # Apply customization zips if present
  apply_customizations

  test_database_connection

  # Because default_master.properties could change on any launch,
  # always do deploy-webapp-pro.

  execute_buildomatic deploy-webapp-pro

  # set Chromium as the JavaScript rendering engine
  config_chromium

  # If JRS_HTTPS_ONLY is set, sets JasperReports Server to
  # run only in HTTPS. Update keystore and password if given
  config_ports_and_ssl

  # start tomcat
  exec env JAVA_OPTS="$JAVA_OPTS" catalina.sh run
}

config_chromium() {
  ## Install chromium at the time of starting of container
  . $DIR/chromium-setup.sh
}

config_ports_and_ssl() {
  #
  # pushing Tomcat to run on HTTP_PORT and HTTPS_PORT
  echo "Tomcat to run on HTTP on ${HTTP_PORT} and HTTPS on ${HTTPS_PORT}"
  sed -i "s/port=\"[0-9]\+\" protocol=\"HTTP\/1.1\"/port=\"${HTTP_PORT}\" protocol=\"HTTP\/1.1\"/" $CATALINA_HOME/conf/server.xml
  sed -i "s/redirectPort=\"[0-9]\+\"/redirectPort=\"${HTTPS_PORT}\"/" $CATALINA_HOME/conf/server.xml

  # if $JRS_HTTPS_ONLY is set in environment to true, disable HTTP support
  # in JasperReports Server.
  JRS_HTTPS_ONLY=${JRS_HTTPS_ONLY:-false}

  if "$JRS_HTTPS_ONLY" = "true"; then
    echo "Setting HTTPS only within JasperReports Server"
    cd $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF
    xmlstarlet ed --inplace \
      -N x="http://java.sun.com/xml/ns/j2ee" -u \
      "//x:security-constraint/x:user-data-constraint/x:transport-guarantee" \
      -v "CONFIDENTIAL" web.xml
    sed -i "s/=http:\/\//=https:\/\//g" js.quartz.properties
    sed -i "s/8080/${HTTPS_PORT:-8443}/g" js.quartz.properties
  else
    echo "NOT! Setting HTTPS only within JasperReports Server. Should actually turn it off, but cannot."
  fi

  SSL_CERT_PATH=${SSL_CERT_PATH:-${MOUNTS_HOME}/ssl-certificate}

  if [ -d "$SSL_CERT_PATH" ]; then
    CERT_PATH_FILES=$(find $SSL_CERT_PATH -iname ".keystore*" \
      -exec readlink -f {} \;)

    # update the keystore and password if there
    if [[ $CERT_PATH_FILES -ne 0 ]]; then
      # will only be one, if at all
      for keystore in $CERT_PATH_FILES; do
        if [[ -f "$keystore" ]]; then
          echo "Deploying SSL Keystore $keystore"
          cp "${keystore}" $CATALINA_HOME/conf
          xmlstarlet ed --inplace --subnode "/Server/Service/Connector[@port='${HTTPS_PORT:-8443}']" --type elem \ 
          --var connector-ssl '$prev' \
            --update '$connector-ssl' --type attr -n port -v "${HTTPS_PORT:-8443}" \
            --update '$connector-ssl' --type attr -n keystoreFile -v "$CATALINA_HOME/conf/${keystore}" \
            --update '$connector-ssl' --type attr -n keystorePass -v "${KS_PASSWORD:-changeit}" \
            ${CATALINA_HOME}/conf/server.xml
          echo "Deployed SSL ${keystore} keystore"
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

  # end if $SSL_CERT_PATH exists.
  fi

}

apply_customizations() {
  # unpack zips (if exist) from path
  # ${MOUNTS_HOME}/customization
  # to JasperReports Server web application path
  # $CATALINA_HOME/webapps/jasperserver-pro/
  # file sorted with natural sort
  JRS_CUSTOMIZATION=${JRS_CUSTOMIZATION:-${MOUNTS_HOME}/customization}
  if [ -d "$JRS_CUSTOMIZATION" ]; then
    echo "Deploying Customizations from $JRS_CUSTOMIZATION"

    JRS_CUSTOMIZATION_FILES=$(find $JRS_CUSTOMIZATION -iname "*zip" \
      -exec readlink -f {} \; | sort -V)
    # find . -path ./lower -prune -o -name "*txt"
    for customization in $JRS_CUSTOMIZATION_FILES; do
      if [[ -f "$customization" ]]; then
        if unzip -l $customization | grep install.sh; then
          echo "Installing ${customization##*/}"
          mkdir -p "/tmp/jrs-installs/${customization##*/}"
          unzip -o "$customization" -d "/tmp/jrs-installs/${customization##*/}"
          cd "/tmp/jrs-installs/${customization##*/}"
          chmod +x -R *.sh
          ./install.sh
          cd ..
          rm -rf "${customization##*/}"
        else
          echo "Unzipping $customization into JasperReports Server webapp $CATALINA_HOME/webapps/jasperserver-pro"
          unzip -o "$customization" \
            -d $CATALINA_HOME/webapps/jasperserver-pro/
        fi
      fi
    done
  fi

  TOMCAT_CUSTOMIZATION=${TOMCAT_CUSTOMIZATION:-${MOUNTS_HOME}/tomcat-customization}
  if [ -d "$TOMCAT_CUSTOMIZATION" ]; then
    echo "Deploying Tomcat Customizations from $TOMCAT_CUSTOMIZATION"
    TOMCAT_CUSTOMIZATION_FILES=$(find $TOMCAT_CUSTOMIZATION -iname "*zip" \
      -exec readlink -f {} \; | sort -V)
    for customization in $TOMCAT_CUSTOMIZATION_FILES; do
      if [[ -f "$customization" ]]; then
        echo "Unzipping $customization into Tomcat"
        unzip -o -q "$customization" \
          -d $CATALINA_HOME
      fi
    done
  fi
}

initialize_deploy_properties

case "$1" in
run)
  shift 1
  run_jasperserver "$@"
  ;;
*)
  exec "$@"
  ;;
esac
