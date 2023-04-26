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
  - [Using JasperReports® Server Installer](#using-jasperreports-server-installer)
  - [Using Docker Run](#using-docker-run)
- [Repository Setup](#repository-setup)
  - [Using Docker Compose](#using-docker-compose-1)
  - [Using Docker Run](#using-docker-run-1)
- [Deploying the JasperReports® Server Application](#deploying-the-jasperreports-server-application)
  - [Using Docker Compose](#using-docker-compose-2)
  - [Using Docker Run](#using-docker-run-2)
- [Deploying the Application in Cluster Mode](#deploying-the-application-in-cluster-mode)
- [Deploying JasperReports Server and Scalable Query Engine](#deploying-jasperreports-server-and-scalable-query-engine)
  <!-- /TOC -->`
  </details>

# Introduction

This distribution includes Dockerfile and supporting files for building, configuring, and running  JasperReports® Server in containers. Orchestration is done by Kubernetes and all the deployment configurations are managed by Helm charts for Kubernetes. ActiveMQ JMS is used for caching.

# Prerequisites

1. Docker-engine (19.x+) setup with Docker Compose  (3.9+)
1. Knowledge of Docker 
1. Git 
1. JasperReports&reg; Server


# Repository Structure

| File/Directory | Description                                                                                                |
|------------|------------------------------------------------------------------------------------------------------------|
|cluster-config| Directory contains all the JasperReports® Server cluster configuration files.                              |
|resources| Directory contains customer-related files.                                                                 |
|scripts| Directory contains Dockerfile scripts.                                                                     |
|.env | Environment variables for Docker Compose files.                                                            |
|Dockerfile| JasperReports® Server web application image based on Tomcat.                                               |
|Dockerfile.buildomatic| JasperReports® Server buildomatic image. It initializes repository, keystore, import, and export.          |
|docker-compose.yml| Configuration file for running web app and buildomatic images via docker-compose.                          |
|cluster-docker-compose.file| Configuration file for running web app images in cluster mode by using HAProxy load balancer via docker-compose. |


# Installer Setup

1. Run `cd <YOUR_SYSTEM_DIR>`.
1. Clone the js-docker repository to the current directory.
      `git@github.com:TIBCOSoftware/js-docker.git   
1. `cd <CONTAINER_PATH>` and Download a commercial edition of JasperReports® Server WAR File installer zip into the current directory.
1. Run `cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/scripts` and then run `./unpackWARInstaller.sh`.

**Note:**  **CONTAINER_PATH=<YOUR_SYSTEM_DIR>/js-docker**

# Docker Build and Run Time Environment Variables

These variables are passed to the command line with `--build-arg` for docker build and to the .env file for docker-compose.yml.

| Environment Variable Name | Description | Default Value                                              |
|------------| -------------|------------------------------------------------------------|
|INSTALL_CHROMIUM| Whether Chromium installed. **Note: Cloud Software Group, Inc. is not liable for license violation of chromium.**| false                                                      |
|JASPERREPORTS_SERVER_APP_IMAGE_NAME| Name of the JasperReports® Server image | jasperserver-webapp                                        |
|JASPERREPORTS_SERVER_BUILDOMATIC_IMAGE_NAME| Name of the JasperReports® Server buildomatic image | jasperserver-buildomatic                                   |
|JASPERREPORTS_SERVER_VERSION|Version number of JasperReports® Server| 8.0.4                                                      |
|JASPERREPORTS_SERVER_APP_IMAGE_TAG|Image tag of the JasperReports® Server web app | 8.0.4                                                      |
|JASPERREPORTS_SERVER_BUILDOMATIC_IMAGE_TAG|Image tag of the JasperReports® Server buildomatic | 8.0.4                                                      |
|TOMCAT_BASE_IMAGE|Tomcat Docker image certified for the version of JasperReports® Server being deployed based on Debian and Amazon Linux 2. It is of two types "tomcat:9.0.65-jdk11-openjdk" for Debian:11 and "tomcat:9.0.73-jdk11-corretto" for Amazon Linux 2 |tomcat:9.0.65-jdk11-openjdk                                |
|JDK_BASE_IMAGE|Java Docker image certified for the version of JasperReports® Server being deployed based on Debian and Amazon Linux 2. It is of two types openjdk:11-jdk and  amazoncorretto:11| openjdk:11-jdk                                             |
RELEASE_DATE|Release date of JasperReports® Server | May 13, 2022                                               |
|JS_INSTALL_TARGETS| Used for repository setup, import, and export. Provides all the lists of ANT targets to perform any buildomatic action in JasperReports® Server. See the JasperReports® Server documentation for more information. | gen-config pre-install-test-pro prepare-all-pro-dbs-normal |

# Building the Images 
`cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs` and update the `.env` file and `./resources/default-properties/default_master.properties`


### Repository Configuration
Update the dbHost in `./resources/default-properties/default_master.properties` with the repository hostname for JasperReports® Server.
In case if an external repository database already exists and loaded, then update **dbHost** to point to the corresponding database host.

If you plan to use repository database in the container, then **dbHost** can be set to:
- host.docker.internal - in case of using docker desktop
- repository-postgresql.default.svc.cluster.local - when PostgreSQL is installed in k8s cluster

### Chromium Configuration 
Update the chrome.path in `Docker/jrs/resources/default-properties/default_master.properties`.
 
|Base Image | Chrome-path|
|-----------|------------|
|tomcat:9.0.65-jdk11-openjdk| /usr/bin/chromium|
|tomcat:9.0.73-jdk11-corretto| /usr/bin/chromium-browser|

**Note on Chromium /dev/shm size limit**

By default, Chromium uses /dev/shm that has 64MB storage to store its internal data and some Operating System images. When exporting large Dashboards in the JasperReports® Server, 64MB may not be enough and users may see Chrome-related timeout exceptions. To resolve it, uncomment the following line in `scripts/entrypoint.sh`.

    echo 'net.sf.jasperreports.chrome.argument.disable-dev-shm-usage=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties



**Note on Chromium Sandbox:**
   
  Some Linux operating systems require Chromium-sandbox and it depends on virtualization. [See here for more information](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/sandboxing.md)

If you see the Chromium issue in  JasperReports® Server using Docker deployment, uncomment the following line in `scripts/entrypoint.sh`.
        
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
## Using JasperReports® Server Installer 
1. Go to `cd <CONTAINER_PATH>/jasperreports-server-pro-<JRS_VERSION>-bin/buildomatic`.
1. Copy the `sample_conf/postgresql_master.properties` to `default_master.properties`.
1. Add `appServerType=skipAppServerCheck` to `default_master.properties` and comment out `appServerType = tomcat`.
1. Run `./js-ant gen-config` and keystore will generate in USER_HOME dir with **.jrsks and .jrsksp** name.
1. Copy the keystore to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore`. 
1. To change the permissions to 644, run `chmod -R 644 .jrs*`.

## Using Docker Run
- Buildomatic image must be created before going on to the next steps.

**Note:** This will run with root user.

`docker run -v <HOST_PATH>:/usr/local/share/jasperserver-pro/keystore --user root jasperserver-buildomatic:<JRS_VERSION> gen-config`

 **.jrsks** and **.jrsksp** keys will be generated in **HOST_PATH** location which is given in the above command.

- Copy the keystore from `HOST_PATH` to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore`

- To change the keystore permission to 644, run `chmod -R 644 .jrs*`.

 See the JasperReports® Server Security Guide at [Jasperserver Official Docs](https://community.jaspersoft.com/documentation) for more information.
   
# Repository Setup

**It is recommended to use Docker Compose.**

## Using Docker Compose

    docker-compose run jasperserver-buildomatic (you can use the same command for the external DB Host and Docker container as DB host)   
 
 **Note:** Although an external repository DB is used, a PostgreSQL container is created, and it does not impact JasperReports® Server. If you don't want to create a PostgreSQL container, then remove repository dependency from jasperserver-buildomatic service in docker-compose.yaml.
 
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

# Deploying the JasperReports® Server Application

**It is recommended to use Docker Compose.**

## Using Docker Compose

   `docker-compose up -d jasperserver-webapp`  (Same command for the external DB Host and Docker container as DB host )
    
- Access the application by using host-name:8080/jasperserver-pro

 **Note:** Although an external repository DB is used, a PostgreSQL container is created, and it does not impact JasperReports® Server. If you don't want to create a PostgreSQL container, then remove repository dependency from jasperserver-webapp service in docker-compose.yaml

## Using Docker Run

 ### Repository Setup Using Docker Container
 
    docker run --name activemq -d rmohr/activemq:5.15.9-alpine
    docker run --link activemq:activemq --link repository:repository  --name jrs_jasperserver-webapp -p 8080:8080 -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license:/usr/local/share/jasperserver-pro/license  -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore -e JAVA_OPTS="-Xmx3500M -Djs.license.directory=/usr/local/share/jasperserver-pro/license -Djasperserver.cache.jms.provider=tcp://activemq:61616 " -d jasperserver-webapp:<jrs_version>

**Note:** Dockerfiles are designed to run in the cluster mode always, to run the JasperReports® Server alone, comment `COPY --chown=jasperserver:jasperserver cluster-config/WEB-INF  $CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/` in Dockerfile and then rebuild the image.

### Repository Setup Using External DB

    docker run --name activemq -d rmohr/activemq:5.15.9-alpine
    docker run --link activemq:activemq   --name jrs_jasperserver-webapp -p 8080:8080 -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license:/usr/local/share/jasperserver-pro/license  -v <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore:/usr/local/share/jasperserver-pro/keystore -e JAVA_OPTS="-Xmx3500M -Djs.license.directory=/usr/local/share/jasperserver-pro/license -Djasperserver.cache.jms.provider=tcp://activemq:61616 " -d jasperserver-webapp:<jrs_version>


# Deploying the Application in Cluster Mode

- It uses haproxy as a load balancer and activemq as a cache replication. Before launching the application, make sure images are created successfully and repository DB setup is also completed.

   `docker-compose -f cluster-docker-compose.yml up -d`

- Wait for the application to start and access the application by using `host-name/jasperserver-pro` (port is not needed, haproxy is running on port 80).


# Deploying JasperReports Server and Scalable Query Engine

1. Set  `scalableQueryEngine.enabled to true` in [default_master.properties](./resources/default-properties/default_master.properties)
1. Update the **SCALABLE_QUERY_ENGINE_URL** with the Hostname or Fqdn in the `.env` file.
1. Update the **jrs.server.host**  with the Host Name or Fqdn  in the following directory. `<CONTAINER_PATH>/Docker/scalableQueryEngine/resources/properties/application.properties `
1. Build the docker images for JasperReports Server and Scalable Query Engine.   
1. Start the JasperReports Server application (see the instructions in [Deploying the JasperReports® Server Application](#deploying-the-jasperreports-server-application) section).
1. Start the Scalable Query Engine by running the below commands: 
   
   
      `cd ../scalableQueryEngine`
      `docker-compose up -d scalable-query-engine`

1. Check the Scalable Query Engine status by using `HOST_NAME:8081/actuator/health`.
1. Access the JasperReports Server application by using `HOST_NAME:8080/jasperserver-pro`.
1. Run any dashboard in JasperReports Server which uses Ad Hoc view (for example, Performance Summary Dashboard) and see the logs in Scalable Query Engine container.
1. To see the logs, run `docker logs <container_name/id>`.
1. To enable the worker logging, add `com.jaspersoft.ji.war.AdhocWorkerForwardingFilter` to the log.
