#!/bin/bash

# This script sets up and runs JasperReports Server on container start.
# Default "run" command, set in Dockerfile, executes run_jasperserver.
# If webapps/jasperserver-pro does not exist, run_jasperserver 
# redeploys webapp. If "jasperserver" database does not exist,
# run_jasperserver redeploys minimal database.
# Additional "init" only calls init_database, which will try to recreate 
# database and fail if DB exists.

# Sets script to fail if any command fails.
set -e

setup_jasperserver() {
  # If environment is not set, uses default values for postgres
  DB_USER=${DB_USER:-postgres}
  DB_PASSWORD=${DB_PASSWORD:-postgres}
  DB_HOST=${DB_HOST:-postgres}
  DB_PORT=${DB_PORT:-5432}
  DB_NAME=${DB_NAME:-jasperserver}

  # Simple default_master.properties. Modify according to
  # JasperReports Server documentation.
  cat >/usr/src/jasperreports-server/buildomatic/default_master.properties\
<<-_EOL_
appServerType=tomcat8
appServerDir=$CATALINA_HOME
dbType=postgresql
dbHost=$DB_HOST
dbUsername=$DB_USER
dbPassword=$DB_PASSWORD
dbPort=$DB_PORT
js.dbName=$DB_NAME
_EOL_

  # Execute js-ant targets for installing/configuring
  # JasperReports Server. Note that js-ant should be
  # executed in buildomatic directory.
  cd /usr/src/jasperreports-server/buildomatic/
  for i in $@; do
    # Default deploy-webapp-pro attempts to remove
    # $CATALINA_HOME/webapps/jasperserver-pro path.
    # This behaviour does not work if mounted volumes are used.
    # Uses unzip to populate webapp directory and non-destructive
    # targets for configuration
    if [ $i == "deploy-webapp-pro" ]; then
      mkdir -p $CATALINA_HOME/webapps/jasperserver-pro ;
      unzip -o -q ../jasperserver-pro.war \
        -d $CATALINA_HOME/webapps/jasperserver-pro
      ./js-ant \
        init-source-paths \
        set-pro-webapp-name \
        deploy-webapp-datasource-configs \
        deploy-jdbc-jar \
        -DwarTargetDir=$CATALINA_HOME/webapps/jasperserver-pro
    else
      # warTargetDir and webaAppName are set as
      # workaround for database configuration regeneration.
      ./js-ant $i \
        -DwarTargetDir=$CATALINA_HOME/webapps/jasperserver-pro \
        -DwebAppName=jasperserver-pro
    fi
  done
}

run_jasperserver() {
  # If jasperserver-pro webapp is not present or if only WEB-INF/logs present
  # in tomcat webapps directory do deploy-webapp-pro.
  # Starts upon webapp deployment as database may still be initializing.
  # This speeds up overall startup because deploy-webapp-pro does
  # not depend on database.
  if [[ -d "$CATALINA_HOME/webapps/jasperserver-pro" ]]; then
    if [[ `ls -1 $CATALINA_HOME/webapps/jasperserver-pro| wc -l` -le 1 \
      || `ls -1 -v $CATALINA_HOME/webapps/jasperserver-pro| head -n 1` \
      =~ "WEB-INF.*" ]]; then
        setup_jasperserver deploy-webapp-pro
    fi
  else
    setup_jasperserver deploy-webapp-pro
  fi

    
  # Wait for PostgreSQL.
  retry_postgresql

  # Force regeneration of database configuration if variable is set.
  # This supports changes to DB configuration for already created
  # container.
  if [[ ${JRS_DBCONFIG_REGEN} ]]; then
    setup_jasperserver deploy-webapp-datasource-configs deploy-jdbc-jar
  fi
 
  # Set up jasperserver database if it is not present.
  if [[ `test_postgresql -l | grep -i ${DB_NAME:-jasperserver} | wc -l` < 1 \
    ]]; then
    setup_jasperserver set-pro-webapp-name \
      create-js-db \
      init-js-db-pro \
      import-minimal-pro
  fi

  # Run deploy-jdbc-jar in the case that the tomcat container has been updated.
  setup_jasperserver deploy-jdbc-jar

  config_license

  # Set up phantomjs.
  config_phantomjs

  # If JRS_HTTPS_ONLY is set, set JasperReports Server to
  # run only in HTTPS.
  config_ssl

  # Apply customization zip if present.
  config_customization

  # Start tomcat.
  catalina.sh run
}

init_database() {
  # Wait for PostgreSQL.
  retry_postgresql
  # Run-only db creation targets.
  setup_jasperserver create-js-db init-js-db-pro import-minimal-pro
}

# Initial license handling.
config_license() {
  # If license file does not exist, copy evaluation license.
  # Non-default location (~/ or /root) used to allow
  # for storing license in a volume. To update license,
  # replace license file and restart container
  JRS_LICENSE=${JRS_LICENSE:-/usr/local/share/jasperreports-pro/license}
  if [[ ! -f \
    "${JRS_LICENSE}/jasperserver.license"\
    ]]; then
    cp /usr/src/jasperreports-server/jasperserver.license \
      /usr/local/share/jasperreports-pro/license
  fi
}

test_postgresql() {
  export PGPASSWORD=${DB_PASSWORD:-postgres}
  psql -h ${DB_HOST:-postgres} -p ${DB_PORT:-5432} -U ${DB_USER:-postgres} $@
}

retry_postgresql() {
  # Retry 5 times to check PostgreSQL is accessible.
  for retry in {1..5}; do
    test_postgresql && echo "PostgreSQL accepting connections" && break || \
      echo "Waiting for PostgreSQL..." && sleep 10;
  done

  # Fail if PostgreSQL is not accessible
  test_postgresql || \
    echo "Error: PostgreSQL on ${DB_HOST:-postgres} not accessible!"
}

config_phantomjs() {
  # if phantomjs binary is present, update JaseperReports Server config.
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

# Apply other runtime configurations.
config_ssl() {
  # If $JRS_HTTPS_ONLY is set in environment to "true", disable HTTP support
  # in JasperReports Server.
  if [[ $JRS_HTTPS_ONLY ]]; then
    cd $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF
    xmlstarlet ed --inplace \
      -N x="http://java.sun.com/xml/ns/j2ee" -u \
      "//x:security-constraint/x:user-data-constraint/x:transport-guarantee"\
      -v "CONFIDENTIAL" web.xml
    sed -i "s/=http:\/\//=https:\/\//g" js.quartz.properties
    sed -i "s/${HTTP_PORT:-8080}/${HTTPS_PORT:-8443}/g" js.quartz.properties
  fi

}

config_customization() {
  # Unpack zips (if they exist) from the path
  # /usr/local/share/jasperreports-pro/customization
  # to the JasperReports Server web application path
  # $CATALINA_HOME/webapps/jasperserver-pro/
  # File sorted with natural sort.
  JRS_CUSTOMIZATION=\
${JRS_CUSTOMIZATION:-/usr/local/share/jasperreports-pro/customization}
  JRS_CUSTOMIZATION_FILES=`find $JRS_CUSTOMIZATION -iname "*zip" \
    -exec readlink -f {} \; | sort -V`
  for customization in $JRS_CUSTOMIZATION_FILES; do
    if [[ -f "$customization" ]]; then
      unzip -o -q "$customization" \
        -d $CATALINA_HOME/webapps/jasperserver-pro/
    fi
  done
}

case "$1" in
  run)
    shift 1
    run_jasperserver "$@"
    ;;
  init)
    init_database
    ;;
  *)
    exec "$@"
esac

