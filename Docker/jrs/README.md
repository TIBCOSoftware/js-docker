<details>
<summary>Table of Contents</summary>
<!-- TOC -->
  
- [Introduction](#introduction) 
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Installer Setup](#installer-setup)
- [Docker Build and Run Time Environment Variables](#docker-build-and-run-time-environment-variables)
- [Building the Images ](#building-the-images )
  - [Using Docker Compose](#using-docker-compose)
  - [Using Docker Build](#using-docker-build)
- [Keystore Generation](#keystore-generation)
  - [Using TIBCO JasperReports® Server Installer](#using-tibco-jasperreports-server-installer)
  - [Using Docker Run](#using-docker-run)
- [Repository Setup](#repository-setup)
  - [Using Docker Compose](#using-docker-compose-1)
  - [Using Docker Run](#using-docker-run-1)
- [Deploying the TIBCO JasperReports® Server Application](#deploying-the-tibco-jasperreports-server-application)
  - [Using Docker Compose](#using-docker-compose-2)
  - [Using Docker Run](#using-docker-run-2)
- [Deploying the Application in Cluster Mode](#deploying-the-application-in-cluster-mode)
  <!-- /TOC -->
  </details>

# Introduction

This distribution includes Dockerfile and supporting files for building, configuring, and running TIBCO JasperReports® Server in containers. Orchestration is done by Kubernetes and all the deployment configurations are managed by Helm charts for Kubernetes. ActiveMQ JMS is used for caching.

# Prerequisites

1. Docker-engine (19.x+) setup with Docker Compose  (3.9+)
1. Knowledge of Docker 
1. Git 
1. TIBCO JasperReports&reg; Server


# Repository Structure

| File/Directory | Description |
|------------| -------------|
|cluster-config|  Directory contains all the TIBCO JasperReports® Server cluster configuration files.|
|resources| Directory contains customer-related files.|
|scripts| Directory contains Dockerfile scripts.|
|.env | Environment variables for Docker Compose files.|
|Dockerfile|TIBCO JasperReports® Server web application image based on Tomcat.|
|Dockerfile.buildomatic|TIBCO JasperReports® Server buildomatic image. It initializes repository, keystore, import, and export.|
|docker-compose.yml|Configuration file for running web app and buildomatic images via docker-compose.|
|cluster-docker-compose.file|Configuration file for running web app images in cluster mode by using HAProxy load balancer via docker-compose.|


# Installer Setup

1. Run `cd <CONTAINER_PATH>`.
1. Download a commercial edition of TIBCO JasperReports® Server WAR File installer zip into the current directory. 
1. Clone the jaspersoft-containers repository to the current directory. 
   `git clone git@github.com:tibco/jaspersoft-containers.git`
1. Run `cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/scripts` and then run `./unpackWARInstaller.sh`.


# Docker Build and Run Time Environment Variables

These variables are passed to the command line with `--build-arg` for docker build and to the .env file for docker-compose.yml.

| Environment Variable Name | Description | Default Value|
|------------| -------------|--------------|
|INSTALL_CHROMIUM| Whether Chromium installed. **Note: TIBCO Software Inc. is not liable for license violation of chromium**.| false|
|JASPERREPORTS_SERVER_APP_IMAGE_NAME| Name of the TIBCO JasperReports® Server Server image | jasperserver-webapp|
|JASPERREPORTS_SERVER_BUILDOMATIC_IMAGE_NAME| Name of the TIBCO JasperReports® Server buildomatic image | jasperserver-buildomatic|
|JASPERREPORTS_SERVER_VERSION|Version number of TIBCO JasperReports® Server  |7.9.0|
|JASPERREPORTS_SERVER_APP_IMAGE_TAG|Image tag of the TIBCO JasperReports® Server web app |7.9.0|
|JASPERREPORTS_SERVER_BUILDOMATIC_IMAGE_TAG|Image tag of the TIBCO JasperReports® Server buildomatic |7.9.0|
|TOMCAT_BASE_IMAGE|Tomcat Docker image certified for the version of TIBCO JasperReports® Server being deployed based on Debian and Amazon Linux 2. It is of two types "tomcat:9.0.37-jdk11-openjdk" for Debian and "tomcat:9.0.37-jdk11-corretto" for Amazon Linux 2 |tomcat:9.0.37-jdk11-openjdk|
|JDK_BASE_IMAGE|Java Docker image certified for the version of TIBCO JasperReports® Server being deployed based on Debian and Amazon Linux 2. It is of two types openjdk:11-jdk and  amazoncorretto:11|openjdk:11-jdk|
RELEASE_DATE|Release date of TIBCO JasperReports® Server | |
|JS_INSTALL_TARGETS| Used for repository setup, import, and export. Provides all the lists of ANT targets to perform any buildomatic action in TIBCO JasperReports® Server. See the TIBCO JasperReports® Server documentation for more information. |gen-config pre-install-test-pro prepare-all-pro-dbs-normal|

# Building the Images 
`cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs` and update the `.env` file and `./resources/default-properties/default_master.properties`

**Note:** If an external repository database does not exist, then update **dbHost=repository** in **default_master.properties** else with working external dbHost Name.

### Chromium Configuration 
Update the chrome.path in `Docker/jrs/resources/default-properties/default_master.properties`.
 
|Base Image | Chrome-path|
|-----------|------------|
|tomcat:9.0.37-jdk11-openjdk| /usr/bin/chromium|
|tomcat:9.0.37-jdk11-corretto| /usr/bin/chromium-browser|

**Note on Chromium /dev/shm size limit**

By default, Chromium uses /dev/shm that has 64MB storage to store its internal data and some Operating System images. When exporting large Dashboards in the TIBCO JasperReports® Server, 64MB may not be enough and users may see Chrome-related timeout exceptions. To resolve it, uncomment the following line in `scripts/entrypoint.sh`.

    echo 'net.sf.jasperreports.chrome.argument.disable-dev-shm-usage=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties

**Note on Chromium Sandbox:**
   
  Some Linux operating systems require Chromium-sandbox and it depends on virtualization. [See here for more information](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/sandboxing.md)

If you see the Chromium issue in TIBCO JasperReports® Server using Docker deployment, uncomment the following line in `scripts/entrypoint.sh`. 
        
    echo 'net.sf.jasperreports.chrome.argument.no-sandbox=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties` 

## Using Docker Compose
**It is recommended to use Docker Compose.**

`cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs`

    docker-compose build
 
## Using Docker Build
``cd <CONTAINER_PATH>``

    docker build -t jasperserver-buildomatic:<version> -f jaspersoft-containers/Docker/jrs/Dockerfile.buildomatic .
    docker build -t jasperserver-webapp:<version> -f jaspersoft-containers/Docker/jrs/Dockerfile .

# Keystore Generation
## Using TIBCO JasperReports® Server Installer 
1. Go to `cd <CONTAINER_PATH>/jasperreports-server-pro-<JRS_VERSION>-bin/buildomatic`.
1. Copy the `sample_conf/postgresql_master.properties` to `default_master.properties`.
1. Add `appServerType=skipAppServerCheck` to `default_master.properties`.
1. Run `./js-ant gen-config` and keystore will generate in USER_HOME dir with **.jrsks and .jrsksp** name.
1. Copy the keystore to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore`. 
1. To change the permissions to 644, run `chmod -R 644 .jrs*`.

## Using Docker Run
- Buildomatic image must be created before going on to the next steps.

**Note:** This will run with root user.

`docker run -v <HOST_PATH>:/usr/local/share/jasperserver-pro/keystore --user root jasperserver-buildomatic:<JRS_VERSION> gen-config`

 **.jrsks and .jrsksp** keys will generate in <HOST_PATH> which is given in the above command.

- Copy the keystore to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore.`

- To change the keystore permission to 644, run `chmod -R 644 .jrs*`.

 See the TIBCO JasperReports® Server Security Guide at [Jasperserver Official Docs](https://community.jaspersoft.com/documentation) for more information. 
   
# Repository Setup

**It is recommended to use Docker Compose.**

## Using Docker Compose

    docker-compose run jasperserver-buildomatic (you can use the same command for the external DB Host and Docker container as DB host)   
 
 **Note:** Although an external repository DB is used, a PostgreSQL container is created, and it does not impact TIBCO JasperReports® Server. If you don't want to create a PostgreSQL container, then remove repository dependency from jasperserver-buildomatic service in docker-compose.yaml.
 
## Using Docker Run

### Repository Setup Using Docker Container
    docker run --name repository -e POSTGRES_PASSWORD=postgres -d postgres:12
    
    Without Samples
    
    docker run  --link repository:repository --name jrs_jasperserver-buildomatic -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore jasperserver-buildomatic:<jrs_version> set-minimal-mode gen-config pre-install-test-pro prepare-js-pro-db-minimal
    
    With Samples
    
    docker run  --link repository:repository --name jrs_jasperserver-buildomatic -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore jasperserver-buildomatic:<jrs_version> gen-config pre-install-test-pro prepare-all-pro-dbs-normal


### Repository Setup Using External Database

    Without Samples
    
    docker run   --name jrs_jasperserver-buildomatic -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore jasperserver-buildomatic:<jrs_version> set-minimal-mode gen-config pre-install-test-pro prepare-js-pro-db-minimal
    
    With Samples
    
    docker run --name jrs_jasperserver-buildomatic   -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore jasperserver-buildomatic:<jrs_version> gen-config pre-install-test-pro prepare-all-pro-dbs-normal

# Deploying the TIBCO JasperReports® Server Application

**It is recommended to use Docker Compose.**

## Using Docker Compose

   `docker-compose up -d jasperserver-webapp`  (Same command for the External DB Host and Docker container as DB host )
    
- Access the application by using `host-name:8080/jasperserver-pro`.

 **Note:** Although an external repository DB is used, a PostgreSQL container is created, and it does not impact TIBCO JasperReports® Server. If you don't want to create a PostgreSQL container, then remove repository dependency from jasperserver-webapp service in docker-compose.yaml

## Using Docker Run

 ### Repository Setup Using Docker Container
 
    docker run --name activemq -d rmohr/activemq:5.15.9-alpine
    docker run --link activemq:activemq --link repository:repository  --name jrs_jasperserver-webapp -p 8080:8080 -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license:/usr/local/share/jasperserver-pro/license  -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore -e JAVA_OPTS="-Xmx3500M -Djs.license.directory=/usr/local/share/jasperserver-pro/license -Djasperserver.cache.jms.provider=tcp://activemq:61616 " -d jasperserver-webapp:<jrs_version>

**Note:** Dockerfiles are designed to run in the cluster mode always, to run the TIBCO JasperReports® Server alone, comment `COPY --chown=jasperserver:jasperserver cluster-config/WEB-INF  $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/` in Dockerfile and then rebuild the image.

### Repository Setup Using External DB

    docker run --name activemq -d rmohr/activemq:5.15.9-alpine
    docker run --link activemq:activemq   --name jrs_jasperserver-webapp -p 8080:8080 -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license:/usr/local/share/jasperserver-pro/license  -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore -e JAVA_OPTS="-Xmx3500M -Djs.license.directory=/usr/local/share/jasperserver-pro/license -Djasperserver.cache.jms.provider=tcp://activemq:61616 " -d jasperserver-webapp:<jrs_version>


# Deploying the Application in Cluster Mode

- It uses haproxy as a load balancer and activemq as a cache replication. Before launching the application, make sure images are created successfully and repository DB setup is also completed.

   `docker-compose -f cluster-docker-compose.yml up -d`

- Wait for the application to start and access the application by using `host-name/jasperserver-pro` (port is not needed, haproxy is running on port 80).

 **Note:** Although an external repository DB is used, a PostgreSQL container is created, and it does not impact TIBCO JasperReports® Server. If you don't want to create a PostgreSQL container, then remove repository dependency from jasperserver-webapp-1 and jasperserver-webapp-2 services in cluster-docker-compose.yaml

