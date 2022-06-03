<details>
<summary>Table of Contents</summary>
<!-- TOC -->
  
- [Introduction](#introduction) 
- [Prerequisites](#prerequisites)
- [Repository Structure](#repository-structure)
- [Installer Setup](#installer-setup)
- [Building the Images ](#building-the-images )
  - [Environment Variables](#environment-variables)
  - [Using Docker Compose](#using-docker-compose)
  - [Using Docker Build](#using-docker-build)
- [Deploying the TIBCO JasperReports&reg; Server Scalable Query Engine Application](#deploying-the-tibco-jasperreports-server-scalable-query-engine-application)
  <!-- /TOC -->`
  </details>

# Introduction

This distribution includes `Dockerfile` and supporting files for building, configuring, and running TIBCO JasperReports&reg; Server Scalable Query Engine in containers. Orchestration is done by Kubernetes
and all the deployment configurations are managed by Helm charts and Redis is used for caching.

 
# Prerequisites

1. Docker-engine (19.x+) setup with Docker Compose (3.9+)
1. Knowledge of Docker
1. Git
1. TIBCO JasperReports&reg; Server
1. Keystore

# Repository Structure

| File/Directory | Description |
|------------| -------------|
| Dockerfile | Scalable Query Engine installation and configuration files. |
| Dockerfile.drivers | It is used to copy the JasperReports Server supported JDBC Drivers to the Scalable Query Engine. |
| docker-compose.yaml | Compose file for Scalable Query Engine to orchestrate the Scalable Query Engine, drivers, and redis services. |
| scripts | Directory contains scripts for Scalable Query Engine. |
| resources/drivers | Directory contains JDBC drivers. |
| resources/keystore | Directory contains the keystore and it should be the same as the JasperReports Server keystore. |
| resources/properties | Directory contains properties files for Scalable Query Engine. |


# Installer Setup

1. Run `cd <CONTAINER_PATH>`.
1. Download a commercial edition of JasperReports Server WAR File installer zip into the current directory.
1. Clone the jaspersoft-containers repository to the current directory.
   `git clone git@github.com:tibco/jaspersoft-containers.git`
1. Run `cd <CONTAINER_PATH>/jaspersoft-containers/Docker/jrs/scripts` and then run `./unpackWARInstaller.sh`.


# Building the Images

## Environment Variables

| Environment Variable Name | Description | Default Value|
|------------| -------------|--------------|
|JASPERREPORTS_SERVER_VERSION | JasperReports Server release version | 8.0.2|
|SCALABLE_QUERY_ENGINE_IMAGE_NAME| Scalable Query Engine image name |scalable-query-engine|
|SCALABLE_QUERY_ENGINE_DRIVER_IMAGE_NAME| Scalable Query Engine JDBC drivers image name| scalable-query-engine-driver|
|SCALABLE_QUERY_ENGINE_DRIVER_IMAGE_TAG| Docker tag for Scalable Query Engine | 8.0.2|
|SCALABLE_QUERY_ENGINE_IMAGE_TAG| Docker tag for Scalable Query Engine Driver | 8.0.2|
|JDK_BASE_IMAGE | Docker image certified for the version of JasperReports Server being deployed based on Debian and Amazon Linux 2, and it is of two types **openjdk:11-jdk** for Debian and **amazoncorretto:11** for Amazon Linux 2 |openjdk:11-jdk|
|ks | .jrsks keystore path |/etc/secrets/keystore|
|ksp | .jrsksp keystore path | /etc/secrets/keystore |
|RELEASE_DATE | JasperReports Server release date | Nov 14, 2021 |


Update the `.env` based on the requirement.

**It is recommended to use Docker Compose**

## Using Docker Compose

`cd <CONTAINER_PATH>/jaspersoft-containers/Docker/scalableQueryEngine` and update the `.env` file.


      docker-compose build

## Using Docker Build
``cd <CONTAINER_PATH>``

    docker build -t scalable-query-engine:<version> -f jaspersoft-containers/Docker/scalableQueryEngine/Dockerfile .
    docker build -t scalable-query-engine-drivers:<version> -f jaspersoft-containers/Docker/scalableQueryEngine/Dockerfile.drivers .


# Deploying the TIBCO JasperReports&reg; Server Scalable Query Engine Application

[Generate the keystore](../jrs/#keystore-generation) if it does not exist and copy it to `./resources/keystore` folder.
**Note** These keystore must be same as JasperReports Server keystore which is used for creating repository DB

      docker network create jrs_default 
      docker-compose up -d scalable-query-engine

**Note:** It is used through JasperReports Server and cannot be accessed directly except health checks.


1. Check the Scalable Query Engine status by using `**HOST_NAME:8081/actuator/health**`.
1. Configure the Scalable Query Engine with JasperReports Server by using `**SCALABLE_QUERY_ENGINE_URL**` as an environment variable. 
1. Restart the JasperReports Server to reflect the new changes.
1. Run any dashboard in JasperReports Server that uses Ad Hoc view (for example, Performance Summary Dashboard) and see the logs in a Scalable Query Engine container.
1. To see the logs, run `docker logs <container_name/id>`.

