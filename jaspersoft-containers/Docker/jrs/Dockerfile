# Copyright (c) 2021-2021. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file

#ARG TOMCAT_BASE_IMAGE=tomcat:9.0.54-jdk11-corretto
ARG TOMCAT_BASE_IMAGE=tomcat:9.0.54-jdk11-openjdk
ARG INSTALL_CHROMIUM=false
ARG JASPERREPORTS_SERVER_VERSION=8.1.0

FROM ${TOMCAT_BASE_IMAGE} as deployment

ARG JASPERREPORTS_SERVER_VERSION
ARG INSTALL_CHROMIUM
ARG CONTAINER_DISTRO=jaspersoft-containers/Docker/jrs
ARG JRS_DISTRO=jasperreports-server-pro-${JASPERREPORTS_SERVER_VERSION}-bin


ENV INSTALL_CHROMIUM ${INSTALl_CHROMIUM:-false}
ENV JASPERREPORTS_SERVER_VERSION ${JASPERREPORTS_SERVER_VERSION:-8.1.0}
ENV JRS_HOME /usr/src/jasperreports-server
ENV BUILDOMATIC_MODE non-interactive

COPY ${JRS_DISTRO}/buildomatic ${JRS_HOME}/buildomatic/
COPY ${JRS_DISTRO}/apache-ant ${JRS_HOME}/apache-ant/
COPY ${JRS_DISTRO}/jasperserver-pro.war  ${JRS_HOME}/
COPY ${CONTAINER_DISTRO}/resources/buildomatic-customization ${JRS_HOME}/buildomatic/
COPY ${CONTAINER_DISTRO}/resources/default-properties ${JRS_HOME}/buildomatic/
COPY ${CONTAINER_DISTRO}/resources/keystore /usr/local/share/jasperserver-pro/keystore
COPY ${CONTAINER_DISTRO}/scripts/installPackagesForJasperserver-pro.sh /usr/local/scripts/installPackagesForJasperserver-pro.sh

RUN chmod +x /usr/src/jasperreports-server/buildomatic/js-* && \
        chmod +x /usr/src/jasperreports-server/apache-ant/bin/* &&\
        chmod +x /usr/local/scripts/*.sh && \
        /usr/local/scripts/installPackagesForJasperserver-pro.sh &&\
        rm -rf $CATALINA_HOME/webapps/ROOT && \
        rm -rf $CATALINA_HOME/webapps/docs && \
        rm -rf $CATALINA_HOME/webapps/examples && \
        rm -rf $CATALINA_HOME/webapps/host-manager && \
        rm -rf $CATALINA_HOME/webapps/manager

RUN useradd -m jasperserver -u 10099 && chown -R jasperserver:root $CATALINA_HOME &&\
                            chown -R jasperserver:root ${JRS_HOME} &&\
                            chown -R jasperserver:root /usr/local/share/jasperserver-pro/keystore
#USER jasperserver
WORKDIR ${JRS_HOME}/buildomatic/
RUN ./js-ant test-pro-all-props check-dbtype-pro test-appServerType-pro deploy-webapp-pro-if-needed
#set-minimal-mode gen-config pre-install-test-pro prepare-js-pro-db-minimal
RUN chgrp -R 0 $CATALINA_HOME && \
    chmod -R g=u $CATALINA_HOME

FROM ${TOMCAT_BASE_IMAGE}

ARG INSTALL_CHROMIUM
ARG JASPERREPORTS_SERVER_VERSION
ARG CONTAINER_DISTRO=jaspersoft-containers/Docker/jrs
ENV RELEASE_DATE ${RELEASE_DATE:- 13-05-2022}


LABEL "org.jasperosft.name"="JasperReports Server" \
      "org.jaspersoft.vendor"="TIBCO Software Inc." \
      "org.jaspersoft.maintainer"="js-support@tibco.com" \
      "org.jaspersoft.version"=$JASPERREPORTS_SERVER_VERSION \
      "org.jaspersoft.release_date"=$RELEASE_DATE \
      "org.jaspersoft.description"="This image will provide a JasperReports Server Web application." \
      "org.jaspersoft.url"="www.jaspersoft.com"

COPY ${CONTAINER_DISTRO}/scripts/entrypoint.sh /usr/local/scripts/entrypoint.sh
COPY ${CONTAINER_DISTRO}/scripts/installPackagesForJasperserver-pro.sh /usr/local/scripts/installPackagesForJasperserver-pro.sh
RUN  chmod +x /usr/local/scripts/*.sh && \
     /usr/local/scripts/installPackagesForJasperserver-pro.sh


RUN useradd  -m jasperserver -u 10099 && chown -R jasperserver:root $CATALINA_HOME && \
    chgrp -R 0 $CATALINA_HOME && \
    chmod -R g=u $CATALINA_HOME

USER 10099

WORKDIR $CATALINA_HOME
COPY --from=deployment --chown=jasperserver:root /usr/local/tomcat .
COPY --chown=jasperserver:root ${CONTAINER_DISTRO}/resources/jasperserver-customization .
COPY --chown=jasperserver:root ${CONTAINER_DISTRO}/cluster-config/WEB-INF  $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/


EXPOSE 8080 8443
ENTRYPOINT ["/usr/local/scripts/entrypoint.sh"]
CMD ["catalina.sh", "run"]
