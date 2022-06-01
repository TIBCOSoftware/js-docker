# Copyright (c) 2021-2021. TIBCO Software Inc.
# This file is subject to the license terms contained
# in the license file that is distributed with this file

#ARG JDK_BASE_IMAGE=amazoncorretto:11
ARG JDK_BASE_IMAGE=openjdk:11-jdk
ARG JASPERREPORTS_SERVER_VERSION=8.0.2

FROM ${JDK_BASE_IMAGE} AS worker

ARG JASPERREPORTS_SERVER_VERSION
ARG CONTAINER_DISTRO=jaspersoft-containers/Docker/scalableQueryEngine
ENV JASPERREPORTS_SERVER_VERSION ${JASPERREPORTS_SERVER_VERSION:-8.0.2}
ARG JRS_DISTRO=jasperreports-server-pro-${JASPERREPORTS_SERVER_VERSION}-bin

ENV WORKER_HOME /usr/local/scalable-query-engine

WORKDIR /usr/local/scalable-query-engine

COPY $CONTAINER_DISTRO/scripts/installPackagesForScalableAdhoc.sh /usr/local/scripts/installPackagesForScalableAdhoc.sh
COPY ${JRS_DISTRO}/scalable-query-engine-${JASPERREPORTS_SERVER_VERSION}.jar scalable-query-engine.jar

RUN chmod +x /usr/local/scripts/installPackagesForScalableAdhoc.sh &&  /usr/local/scripts/installPackagesForScalableAdhoc.sh && \
    useradd -m jasperserver -u 11099 && chown -R jasperserver:root /usr/local/scalable-query-engine &&\
    java -Djarmode=layertools -jar scalable-query-engine.jar extract && \
    chgrp -R 0 $WORKER_HOME && \
    chmod -R g=u $WORKER_HOME

FROM ${JDK_BASE_IMAGE}

ARG JASPERREPORTS_SERVER_VERSION
ENV RELEASE_DATE ${RELEASE_DATE:- 13-05-2022}

LABEL "org.jasperosft.name"="Jasper Reports Server Scalable Query Engine" \
      "org.jaspersoft.vendor"="Tibco Software Inc." \
      "org.jaspersoft.maintainer"="js-eng-infra@tibco.com" \
      "org.jaspersoft.version"=$JASPERREPORTS_SERVER_VERSION \
      "org.jaspersoft.release_date"=$RELEASE_DATE \
      "org.jaspersoft.description"="This image will provide a Scalable Query Engine setup" \
      "org.jaspersoft.url"="www.jaspersoft.com"

ENV WORKER_HOME /usr/local/scalable-query-engine
ARG CONTAINER_DISTRO=jaspersoft-containers/Docker/scalableQueryEngine
COPY $CONTAINER_DISTRO/scripts/installPackagesForScalableAdhoc.sh /usr/local/scripts/installPackagesForScalableAdhoc.sh

WORKDIR /usr/local/scalable-query-engine

RUN chmod +x /usr/local/scripts/installPackagesForScalableAdhoc.sh  &&\
    /usr/local/scripts/installPackagesForScalableAdhoc.sh && \
    mkdir -p /tmp &&\
    useradd -m jasperserver -u 11099 && chown -R jasperserver:root $WORKER_HOME /tmp &&\
    chgrp -R 0 $WORKER_HOME /tmp && \
    chmod -R g=u $WORKER_HOME /tmp

USER 11099

COPY --from=worker --chown=jasperserver:root /usr/local/scalable-query-engine/dependencies/ .
COPY --from=worker --chown=jasperserver:root /usr/local/scalable-query-engine/spring-boot-loader/ .
COPY --from=worker --chown=jasperserver:root /usr/local/scalable-query-engine/snapshot-dependencies/ .
COPY --from=worker --chown=jasperserver:root /usr/local/scalable-query-engine/application/ .

ENTRYPOINT ["java", "org.springframework.boot.loader.PropertiesLauncher"]