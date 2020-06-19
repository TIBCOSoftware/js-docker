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

ARG TOMCAT_BASE_IMAGE=tomcat:9.0.27-jdk11-openjdk
FROM ${TOMCAT_BASE_IMAGE}

ARG DN_HOSTNAME
ARG KS_PASSWORD
ARG JRS_HTTPS_ONLY
ARG HTTP_PORT
ARG HTTPS_PORT
ARG POSTGRES_JDBC_DRIVER_VERSION
ARG JASPERREPORTS_SERVER_VERSION
ARG EXPLODED_INSTALLER_DIRECTORY

ENV PHANTOMJS_VERSION         ${PHANTOMJS_VERSION:-2.1.1}
ENV DN_HOSTNAME         ${DN_HOSTNAME:-localhost.localdomain}
ENV KS_PASSWORD         ${KS_PASSWORD:-changeit}
ENV JRS_HTTPS_ONLY         ${JRS_HTTPS_ONLY:-false}
ENV HTTP_PORT             ${HTTP_PORT:-8080}
ENV HTTPS_PORT             ${HTTPS_PORT:-8443}
ENV POSTGRES_JDBC_DRIVER_VERSION ${POSTGRES_JDBC_DRIVER_VERSION:-42.2.5}
ENV JASPERREPORTS_SERVER_VERSION ${JASPERREPORTS_SERVER_VERSION:-7.5.0}
ENV EXPLODED_INSTALLER_DIRECTORY ${EXPLODED_INSTALLER_DIRECTORY:-resources/jasperreports-server-pro-$JASPERREPORTS_SERVER_VERSION-bin}

# This Dockerfile requires an exploded JasperReports Server WAR file installer file 
# EXPLODED_INSTALLER_DIRECTORY (default jasperreports-server-bin/) directory below the Dockerfile.

RUN mkdir -p /usr/src/jasperreports-server

# get the WAR and license
COPY ${EXPLODED_INSTALLER_DIRECTORY}/jasperserver-pro $CATALINA_HOME/webapps/jasperserver-pro/
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

COPY scripts /

RUN echo "nameserver 8.8.8.8" | tee /etc/resolv.conf > /dev/null && \
    chmod +x /*.sh && \
    /installPackagesForJasperserver-pro.sh > /dev/null && \
	echo "finished installing packages" && \
    rm -rf $CATALINA_HOME/webapps/ROOT && \
    rm -rf $CATALINA_HOME/webapps/docs && \
    rm -rf $CATALINA_HOME/webapps/examples && \
    rm -rf $CATALINA_HOME/webapps/host-manager && \
    rm -rf $CATALINA_HOME/webapps/manager && \
    #
	cp -R /buildomatic /usr/src/jasperreports-server/buildomatic && \
	rm /installPackagesForJasperserver*.sh && rm -rf /buildomatic && \
    chmod +x /usr/src/jasperreports-server/buildomatic/js-* && \
    chmod +x /usr/src/jasperreports-server/apache-ant/bin/* && \
    java -version && \
# Extract phantomjs, move to /usr/local/share/phantomjs, link to /usr/local/bin.
# Comment out if phantomjs not required.
    wget "https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2" \
        -O /tmp/phantomjs.tar.bz2 --no-verbose && \
    tar -xjf /tmp/phantomjs.tar.bz2 -C /tmp && \
    rm -f /tmp/phantomjs.tar.bz2 && \
    mv /tmp/phantomjs*linux-x86_64 /usr/local/share/phantomjs && \
    ln -sf /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin && \
# In case you wish to download from a different location you can manually
# download the archive and copy from resources/ at build time. Note that you
# also # need to comment out the preceding RUN command
#COPY resources/phantomjs*bz2 /tmp/phantomjs.tar.bz2
#RUN tar -xjf /tmp/phantomjs.tar.bz2 -C /tmp && \
#    rm -f /tmp/phantomjs.tar.bz2 && \
#    mv /tmp/phantomjs*linux-x86_64 /usr/local/share/phantomjs && \
#    ln -sf /usr/local/share/phantomjs/bin/phantomjs /usr/local/bin && \
    rm -rf /tmp/* && \
    #
    wget "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_DRIVER_VERSION}.jar"  \
        -P /usr/src/jasperreports-server/buildomatic/conf_source/db/postgresql/jdbc --no-verbose && \
#
# Configure tomcat for SSL by default with a self-signed certificate.
# Option to set up JasperReports Server to use HTTPS only.
#
    keytool -genkey -alias self_signed -dname "CN=${DN_HOSTNAME}" \
        -storetype PKCS12 \
        -storepass "${KS_PASSWORD}" \
        -keypass "${KS_PASSWORD}" \
        -keystore /root/.keystore.p12 && \
    keytool -list -keystore /root/.keystore.p12 -storepass "${KS_PASSWORD}" -storetype PKCS12 && \
    xmlstarlet ed --inplace --subnode "/Server/Service" --type elem \ 
        -n Connector -v "" --var connector-ssl '$prev' \
    --insert '$connector-ssl' --type attr -n port -v "${HTTPS_PORT}" \
    --insert '$connector-ssl' --type attr -n protocol -v \ 
        "org.apache.coyote.http11.Http11NioProtocol" \
    --insert '$connector-ssl' --type attr -n maxThreads -v "150" \
    --insert '$connector-ssl' --type attr -n SSLEnabled -v "true" \
    --insert '$connector-ssl' --type attr -n scheme -v "https" \
    --insert '$connector-ssl' --type attr -n secure -v "true" \
    --insert '$connector-ssl' --type attr -n clientAuth -v "false" \
    --insert '$connector-ssl' --type attr -n sslProtocol -v "TLS" \
    --insert '$connector-ssl' --type attr -n keystorePass \
        -v "${KS_PASSWORD}"\
    --insert '$connector-ssl' --type attr -n keystoreFile \
        -v "/root/.keystore.p12" \
    ${CATALINA_HOME}/conf/server.xml

# Expose ports. Note that you must do one of the following:
# map them to local ports at container runtime via "-p 8080:8080 -p 8443:8443"
# or use dynamic ports.
EXPOSE ${HTTP_PORT} ${HTTPS_PORT}

ENTRYPOINT ["/entrypoint.sh"]

# Default action executed by entrypoint script.
CMD ["run"]
