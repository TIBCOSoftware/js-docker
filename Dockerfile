# Copyright (c) 2020. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file.

# Tomcat official Docker Hub images are not using Oracle anymore, hence the rename
#FROM tomcat:9.0-jre8

# set certified Tomcat+JRE image version for the JasperReports Server
# Certified version of Tomcat for JasperReports Server 7.2.0 commercial editions
# ARG TOMCAT_BASE_IMAGE=tomcat:9.0.17-jre8

# Certified version of Tomcat for JasperReports Server 7.5.0 commercial editions
# ARG TOMCAT_BASE_IMAGE=tomcat:9.0-jdk11-corretto

# Certified version of Tomcat for JasperReports Server 7.8.0 and 7.9.0 commercial editions
# ARG TOMCAT_BASE_IMAGE=tomcat:9.0.37-jdk11-corretto

ARG TOMCAT_BASE_IMAGE=tomcat:9.0.37-jdk11-openjdk
FROM ${TOMCAT_BASE_IMAGE}

ARG DN_HOSTNAME
ARG KS_PASSWORD
ARG JRS_HTTPS_ONLY
ARG HTTP_PORT
ARG HTTPS_PORT
ARG JAVASCRIPT_RENDERING_ENGINE
ARG POSTGRES_JDBC_DRIVER_VERSION
ARG JASPERREPORTS_SERVER_VERSION
ARG EXPLODED_INSTALLER_DIRECTORY

ENV DN_HOSTNAME         ${DN_HOSTNAME:-localhost.localdomain}
ENV KS_PASSWORD         ${KS_PASSWORD:-changeit}
ENV JRS_HTTPS_ONLY      ${JRS_HTTPS_ONLY:-false}
ENV HTTP_PORT           ${HTTP_PORT:-8080}
ENV HTTPS_PORT          ${HTTPS_PORT:-8443}
ENV JAVASCRIPT_RENDERING_ENGINE  ${JAVASCRIPT_RENDERING_ENGINE:-chromium}

ENV POSTGRES_JDBC_DRIVER_VERSION ${POSTGRES_JDBC_DRIVER_VERSION:-42.2.5}
ENV JASPERREPORTS_SERVER_VERSION ${JASPERREPORTS_SERVER_VERSION:-7.9.0}
ENV EXPLODED_INSTALLER_DIRECTORY ${EXPLODED_INSTALLER_DIRECTORY:-resources/jasperreports-server-pro-$JASPERREPORTS_SERVER_VERSION-bin}

# This Dockerfile requires an exploded JasperReports Server WAR file installer file
# EXPLODED_INSTALLER_DIRECTORY (default jasperreports-server-bin/) directory below the Dockerfile.

# deploy the WAR to Tomcat
COPY ${EXPLODED_INSTALLER_DIRECTORY}/jasperserver-pro $CATALINA_HOME/webapps/jasperserver-pro/

#copy copyright notices
COPY ${EXPLODED_INSTALLER_DIRECTORY}/TIB* /usr/src/jasperreports-server/

# Ant
COPY ${EXPLODED_INSTALLER_DIRECTORY}/apache-ant /usr/src/jasperreports-server/apache-ant/

# js-ant script, Ant XMLs and support in bin
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/js-ant /usr/src/jasperreports-server/buildomatic/
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/build.xml /usr/src/jasperreports-server/buildomatic/
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/bin/*.xml /usr/src/jasperreports-server/buildomatic/bin/
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/bin/app-server /usr/src/jasperreports-server/buildomatic/bin/app-server/
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/bin/groovy /usr/src/jasperreports-server/buildomatic/bin/groovy/

# supporting resources
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/conf_source /usr/src/jasperreports-server/buildomatic/conf_source/
COPY ${EXPLODED_INSTALLER_DIRECTORY}/buildomatic/lib /usr/src/jasperreports-server/buildomatic/lib/

# js-docker specific scripts and resources
COPY scripts /usr/src/jasperreports-server/scripts/

RUN chmod +x /usr/src/jasperreports-server/scripts/*.sh && \
    /usr/src/jasperreports-server/scripts/installPackagesForJasperserver-pro.sh && \
    rm -rf $CATALINA_HOME/webapps/ROOT && \
    rm -rf $CATALINA_HOME/webapps/docs && \
    rm -rf $CATALINA_HOME/webapps/examples && \
    rm -rf $CATALINA_HOME/webapps/host-manager && \
    rm -rf $CATALINA_HOME/webapps/manager && \
    #
	cp -R /usr/src/jasperreports-server/scripts/buildomatic /usr/src/jasperreports-server/buildomatic && \
    chmod +x /usr/src/jasperreports-server/buildomatic/js-* && \
    chmod +x /usr/src/jasperreports-server/apache-ant/bin/* && \
    java -version && \
    #rm -rf /tmp/* && \
    #
    wget "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_DRIVER_VERSION}.jar"  \
        -P /usr/src/jasperreports-server/buildomatic/conf_source/db/postgresql/jdbc --no-verbose
# Expose ports. Note that you must do one of the following:
# map them to local ports at container runtime via "-p 8080:8080 -p 8443:8443"
# or use dynamic ports.
EXPOSE ${HTTP_PORT} ${HTTPS_PORT}

ENTRYPOINT ["/usr/src/jasperreports-server/scripts/entrypoint.sh"]

# Default action executed by entrypoint script.
CMD ["run"]
