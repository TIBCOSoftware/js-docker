<details>
<summary>Table of Contents</summary>
<!-- TOC -->
  
- [Introduction](#introduction) 
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Installer Setup](#installer-setup)
- [Docker Build and Run Time Environment Variables](#docker-build-and-run-time-environment-variables)
- [Building the Images ](#building-the-images)
  - [Using Docker Compose](#using-docker-compose)
  - [Using Docker Build](#using-docker-build)
- [Keystore Generation](#keystore-generation)
  - [Using TIBCO JasperReports® Server Installer](#using-tibco-jasperreports-server-installer)
  - [Using Docker Run](#using-docker-run)
- [Repository Setup](#repository-setup)
  - [Using Docker Compose](#using-docker-compose-1)
  - [Using Docker Run](#using-docker-run-1)
- [Deploying the TIBCO JasperReports® Server Application](#deploying-the-tibco-jasperreports-server-application)
  - [Install JasperReports® Server license](#install-jasperreports-server-license)
  - [Using Docker Compose](#using-docker-compose-2)
  - [Using Docker Run](#using-docker-run-2)
- [Deploying the Application in Cluster Mode](#deploying-the-application-in-cluster-mode)
- [Deploying JasperReports Server and Scalable Query Engine](#deploying-jasperreports-server-and-scalable-query-engine)
  <!-- /TOC -->`
  </details>

# Introduction

This distribution includes Dockerfile and supporting files for building, configuring, and running TIBCO JasperReports® Server in containers. Orchestration is done by Kubernetes and all the deployment configurations are managed by Helm charts for Kubernetes. ActiveMQ JMS is used for caching.

# Prerequisites

1. Docker-engine (19.x+) setup with Docker Compose  (3.9+)
1. Knowledge of Docker 
1. Git 
1. TIBCO JasperReports&reg; Server

# Step-by-step Guide to deploy TIBCO JasperReports® Server on Docker
To deploy TIBCO JasperReports&reg; Server Cluster from scratch using **docker compose**, you can follow instructions at [Deploying JasperReports Server and Scalable Query Engine](#deploying-jasperreports-server-and-scalable-query-engine)

# Repository Structure

| File/Directory | Description |
|------------| -------------|
|cluster-config| Directory contains all the TIBCO JasperReports® Server cluster configuration files.|
|resources| Directory contains customer-related files.|
|scripts| Directory contains Dockerfile scripts.|
|.env | Environment variables for Docker Compose files.|
|Dockerfile|TIBCO JasperReports® Server web application image based on Tomcat.|
|Dockerfile.buildomatic|TIBCO JasperReports® Server buildomatic image. It initializes repository, keystore, import, and export.|
|docker-compose.yml|Configuration file for running web app and buildomatic images via docker-compose.|
|cluster-docker-compose.file|Configuration file for running web app images in cluster mode by using HAProxy load balancer via docker-compose.|


# Installer Setup

1. Run `cd <YOUR_SYSTEM_DIR>`.
2. Clone the js-docker repository to the current directory:<br/>`git clone git@github.com:TIBCOSoftware/js-docker.git`
3. `cd <CONTAINER_PATH>` and Download a commercial edition of TIBCO JasperReports® Server WAR File installer zip into the current directory.
4. Run `cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/scripts` and then run `./unpackWARInstaller.sh`.

**Note:**  **CONTAINER_PATH=<YOUR_SYSTEM_DIR>/js-docker**

# Docker Build and Run Time Environment Variables

These variables are passed to the command line with `--build-arg` for docker build and to the .env file for docker-compose.yml.

| Environment Variable Name | Description | Default Value|
|------------| -------------|--------------|
|INSTALL_CHROMIUM| Whether Chromium installed. **Note: TIBCO Software Inc. is not liable for license violation of chromium.**| false|
|JASPERREPORTS_SERVER_APP_IMAGE_NAME| Name of the TIBCO JasperReports® Server image | jasperserver-webapp|
|JASPERREPORTS_SERVER_BUILDOMATIC_IMAGE_NAME| Name of the TIBCO JasperReports® Server buildomatic image | jasperserver-buildomatic|
|JASPERREPORTS_SERVER_VERSION|Version number of TIBCO JasperReports® Server|8.1.1|
|JASPERREPORTS_SERVER_APP_IMAGE_TAG|Image tag of the TIBCO JasperReports® Server web app |8.1.1|
|JASPERREPORTS_SERVER_BUILDOMATIC_IMAGE_TAG|Image tag of the TIBCO JasperReports® Server buildomatic |8.1.1|
|TOMCAT_BASE_IMAGE|Tomcat Docker image certified for the version of TIBCO JasperReports® Server being deployed based on Debian and Amazon Linux 2. It is of two types "tomcat:9.0.54-jdk11-openjdk" for Debian and "tomcat:9.0.54-jdk11-corretto" for Amazon Linux 2 |tomcat:9.0.54-jdk11-openjdk|
|JDK_BASE_IMAGE|Java Docker image certified for the version of TIBCO JasperReports® Server being deployed based on Debian and Amazon Linux 2. It is of two types openjdk:11-jdk and  amazoncorretto:11|openjdk:11-jdk|
RELEASE_DATE|Release date of TIBCO JasperReports® Server | May 13, 2022 |
|JS_INSTALL_TARGETS| Used for repository setup, import, and export. Provides all the lists of ANT targets to perform any buildomatic action in TIBCO JasperReports® Server. For more information, see the TIBCO JasperReports® Server documentation . |gen-config pre-install-test-pro prepare-all-pro-dbs-normal|

# Building the Images 
`cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs` and update the `.env` file and `./resources/default-properties/default_master.properties`


### Repository Configuration
Update the dbHost in `./resources/default-properties/default_master.properties` with the repository hostname for TIBCO JasperReports® Server.
In case if an external repository database already exists and loaded, then update **dbHost** to point to the corresponding database host.

If you plan to use repository database in the container, then **dbHost** can be set to:
- host.docker.internal - in case of using docker desktop
- repository - in case of using docker compose (host should be the same as service name in docker-compose.yml)
- repository-postgresql.default.svc.cluster.local - when PostgreSQL is installed in k8s cluster

### Chromium Configuration 
Update the chrome.path in `Docker/jrs/resources/default-properties/default_master.properties`.
 
|Base Image | Chrome-path|
|-----------|------------|
|tomcat:9.0.54-jdk11-openjdk| /usr/bin/chromium|
|tomcat:9.0.54-jdk11-corretto| /usr/bin/chromium-browser|

**Note on Chromium /dev/shm size limit**

By default, Chromium uses /dev/shm that has 64MB storage to store its internal data and some Operating System images. When exporting large Dashboards in the TIBCO JasperReports® Server, 64MB may not be enough and users may see Chrome-related timeout exceptions. To resolve it, uncomment the following line in `scripts/entrypoint.sh`.

    echo 'net.sf.jasperreports.chrome.argument.disable-dev-shm-usage=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties



**Note on Chromium Sandbox:**
   
  Some Linux operating systems require Chromium-sandbox and it depends on virtualization. [See here for more information](https://chromium.googlesource.com/chromium/src/+/HEAD/docs/linux/sandboxing.md)

If you see the Chromium issue in TIBCO JasperReports® Server using Docker deployment, uncomment the following line in `scripts/entrypoint.sh`.
        
    echo 'net.sf.jasperreports.chrome.argument.no-sandbox=true' >>$CATALINA_HOME/webapps/jasperserver-pro/WEB-INF/classes/jasperreports.properties` 

### JasperReports® Server and Buildomatic customization
If you plan to work with **default** JasperReports® Server and buildomatic setup, you can skip this step. In case if you want to apply certain configurations or customizations, for example, changing some settings in `jasperserver-pro/WEB-INF/classes/jasperreports.properties` or some `jasperserver-pro/WEB-INF/applicationContext-*` files, refer to:
- [jasperserver customization guide ](resources/jasperserver-customization/README.md)
- [buildomatic customization guide ](resources/buildomatic-customization/README.md)

## Using Docker Compose
**Note:** Following tasks can be performed using either docker run or docker-compose. Pick the one which is suitable for your use case.

**It is recommended to use Docker Compose.**

**If you perform installation using docker-compose, then you can skip all docker run commands.**

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
1. Add `appServerType=skipAppServerCheck` to `default_master.properties` and comment out `appServerType = tomcat`.
1. Run `./js-ant gen-config`, as the result keystore and keystore-properties files will be generated in `USER_HOME` dir with **.jrsks and .jrsksp** name.
1. Copy the keystore to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore`. 
1. Change the permissions to 644 for keystore files, run `chmod -R 644 .jrs*`.

## Using Docker Run
- Buildomatic image must be created before going to the next steps.

**Note:** This will run with root user.

`docker run -v <HOST_PATH>:/usr/local/share/jasperserver-pro/keystore --user root jasperserver-buildomatic:<JRS_VERSION> gen-config`

 **.jrsks** and **.jrsksp** keys will be generated in **HOST_PATH** location which is given in the above command.

- Copy the keystore from `HOST_PATH` to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/keystore`

- To change the keystore permission to 644, run `chmod -R 644 .jrs*`.

 For more information, see the TIBCO JasperReports® Server Security Guide at [Jasperserver Official Docs](https://community.jaspersoft.com/documentation).
   
# Repository Setup

**It is recommended to use Docker Compose.**

## Using Docker Compose
`cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs`

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

## Install JasperReports® Server license
1. To install JasperReports® Server license, copy obtained license file into `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license`.
2. Set the permissions to 644 for license file `chmod 644 <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license/jasperserver.license`.


## Using Docker Compose
**It is recommended to use Docker Compose.**

   `docker-compose up -d jasperserver-webapp` (Same command for the external DB Host and Docker container as DB host )
    
- Access the application by using host-name:8080/jasperserver-pro

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
- Update the value of parameter 'replicas' in cluster-docker-compose.yml file depending upon how many containers you would want to create.

   `docker-compose -f cluster-docker-compose.yml up -d`

- Wait for the application to start and access the application by using `host-name/jasperserver-pro` (port is not needed, haproxy is running on port 80).


# Deploying JasperReports Server and Scalable Query Engine

1. Setup Docker and JasperReports® Server, see the instructions at the [Installer Setup](#installer-setup) section.
2. Configure `default_master.properties`, see the instructions at the [Building the Images ](#building-the-images) section.
3. Set  `scalableQueryEngine.enabled to true` in [default_master.properties](./resources/default-properties/default_master.properties).
4. Edit `<CONTAINER_PATH>/Docker/jrs/.env` by setting the **SCALABLE_QUERY_ENGINE_URL** to use the Hostname or Fqdn:
   - for docker desktop on Windows, use the hostname `host.docker.internal`
   - for docker on Linux, use machine Hostname or Fqdn
5. Update the **jrs.server.host**  with the Hostname or Fqdn in the following directory:              `<CONTAINER_PATH>/Docker/scalableQueryEngine/resources/properties/application.properties `
6. Build the docker images for JasperReports® Server by using following commands:
   1. `cd <CONTAINER_PATH>/Docker/jrs`
   2. Run `docker-compose build`
7. Build the docker image for Scalable Query Engine by using following commands:
   1. `cd <CONTAINER_PATH>/Docker/scalableQueryEngine`
   2. Run `docker-compose build`
8. If keystore files (jrsks, jrsksp) do not exist, generate them. You can find information about generating keystore files at the [Using TIBCO JasperReports® Server Installer](#using-tibco-jasperreports-server-installer) section.
9. Copy jrsks, jrsksp into jrs and scalableQueryEngine folders, then keystore files location can be mapped as volume:
   1. copy .jrsks, .jrsksp into `<CONTAINER_PATH>/Docker/jrs/resources/keystore`
   2. copy .jrsks, .jrsksp  into `<CONTAINER_PATH>/Docker/scalableQueryEngine/resources/keystore`
   3. Set the permissions for each keystore file under `<CONTAINER_PATH>/Docker/jrs/resources/keystore` and `<CONTAINER_PATH>/Docker/scalableQueryEngine/resources/keystore`:  `chmod -R 644 .jrs*`.
10. Copy JasperReports® Server license to `<CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/resources/license`, for more information, see the [Install JasperReports® Server license](#install-jasperreports-server-license) section.
11. Set up and load repository database by using following commands:
    1. `cd <CONTAINER_PATH>/Docker/jrs`
    2. Run `docker-compose run jasperserver-buildomatic`
12. Start the JasperReports® Server application, for more information, see [Deploying the TIBCO JasperReports® Server Application](#deploying-the-tibco-jasperreports-server-application) section.
    1. `cd <CONTAINER_PATH>/Docker/jrs`
    2. Run `docker-compose up -d jasperserver-webapp`
13. Start the Scalable Query Engine by using following commands:
    1. `cd <CONTAINER_PATH>/Docker/scalableQueryEngine`
    2. Run `docker-compose up -d scalable-query-engine`
14. Access the JasperReports® Server application by using `HOST_NAME:8080/jasperserver-pro`. 
15. Check the Scalable Query Engine status by using `HOST_NAME:8081/actuator/health`.
16. Run any dashboard in JasperReports® Server which uses an Ad Hoc view (for example, Performance Summary Dashboard) and see the logs in Scalable Query Engine container.
17. To see the logs, run `docker logs <container_name/id>`.
18. To enable the worker logging, login to JasperReports® Server, go to Log Settings and add `com.jaspersoft.ji.war.AdhocWorkerForwardingFilter` to the `DEBUG`.
