# TIBCO  JasperReports&reg; Server for Containers

# Table of contents

1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
1. [Installation](#installation)
   1. [Get the JasperReports Server container configuration](#get-the-js-docker-dockerfile-and-supporting-resources)
   1. [js-docker Repository structure](#the-installed-repository-structure)
   1. [Building JasperReports Server images](#building-jasperreports-server-images)
     1. [Prepare the resources for the images](#prepare-the-resources-for-the-images)
     1. [docker build time environment variables](#docker-build-time-environment-variables)
     1. [Build the images](#build-the-images)
1. [docker run time environment variables](#docker-run-time-environment-variables)
1. [Configuring JasperReports Server with volumes](#configuring-jasperreports-server-with-volumes)
   1. [Using data volumes](#using-data-volumes)
   1. [JasperReports Server use of volumes](#jasperreports-server-use-of-volumes)
   1. [Setting volumes](#setting-volumes)
   1. [Paths to data volumes on Mac and Windows](#paths-to-data-volumes-on-mac-and-windows)
1. [Initializing the JasperReport Server Repository](#initializing-the-jasperreport-server-repository)
   1. [Using a pre-existing database server](#using-a-pre-existing-database)
   1. [Using a database container](#using-a-database-container)
1. [Building and running with docker-compose](#building-and-running-with-docker-compose)
1. [Import and Export for the JasperReports Server repository](#import-and-export) 
   1. [Export from a JasperReports Server repository](#exporting-to-a-jasperreports-server-repository)
   1. [Import into a JasperReports Server repository](#importing-from-a-jasperreports-server-repository)
1. [JasperReports Server logs](#jasperreports-server-logs)
1. [Logging in to JasperReports Server](#logging-in-to-jasperreports-server)
1. [Troubleshooting](#troubleshooting)
   1. [Unable to download phantomjs](#unable-to-download-phantomjs)
   1. ["No route to host" error on a VPN/network with mask](#-no-route-to-host-error-on-a-vpn-or-network-with-mask)
   1. [`docker volume inspect` returns incorrect paths on MacOS X](#-docker-volume-inspect-returns-incorrect-paths-on-macos-x)
   1. [`docker-compose up` fails with permissions error](#-docker-compose-up-fails-with-permissions-error)
   1. [Connection to repository database fails](#connection-to-repository-database-fails)
1. [Docker documentation](#docker-documentation)

# Introduction

This distribution includes `Dockerfile`s and supporting files for building, configuring, and running TIBCO JasperReports&reg; Server commercial editions in containers. Orchestration via Kubernetes, AWS and Helm are outlined as options.  These samples can be used as is or modified to meet the needs of your environment. 
The distribution can be downloaded from [https://github.com/TIBCOSoftware/js-docker](#https://github.com/TIBCOSoftware/js-docker).

This configuration has been certified using
the PostgreSQL 9 database with JasperReports Server 6.4+
and with PostgreSQL 10 for JasperReports Server 7.2+

Basic knowledge of Docker and the underlying infrastructure is required.
For more information about Docker see the
[official documentation for Docker](https://docs.docker.com/).

For more information about JasperReports Server, see the
[Jaspersoft community](http://community.jaspersoft.com/).

# Prerequisites

The following software is required or recommended:

- [docker-engine](https://docs.docker.com/engine/installation) version 1.12 or higher
- (*recommended*):
  - [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
  - [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)
- (*optional*) [docker-compose](https://docs.docker.com/compose/install) version 1.12 or higher
- (*optional*) [git](https://git-scm.com/downloads)
- (*required*) TIBCO Jaspersoft&reg; commercial license.
- Contact your sales
representative for information about licensing. If you do not specify a
TIBCO Jaspersoft license, the evaluation license is used.
- (*optional*) Preconfigured PostgreSQL, MySQL, Oracle, SQL Server or DB2 database. If you do not
currently have a database instance, you can create a database container
at deployment time.

# Installation

## Get the js-docker Dockerfile and supporting resources

Download the js-docker repository as a zip and unzip it, or clone the repository from Github.

To download a zip of js-docker:
- Go to [https://github.com/TIBCOSoftware/js-docker](https://github.com/TIBCOSoftware/js-docker)
- Select Download ZIP on the right hand side of the screen.
![Download ZIP or Clone](js-docker-clone-download.png)

Select Open in Desktop if you have a Git Desktop installed. This will clone the repository for you.
 
If you have the Git command line installed, you can clone the JasperReports Server Docker github repository at 
[https://github.com/TIBCOSoftware/js-docker](https://github.com/TIBCOSoftware/js-docker)

```console
$ git clone https://github.com/TIBCOSoftware/js-docker
$ cd js-docker
```

## The installed Repository structure

The js-docker github repository contains:

| Repository file/directory | Notes |
| ------------ | ------------- |
| `Dockerfile` | JasperReports Server web application image. Based on Tomcat. |
| `Dockerfile-cmdline` | JasperReports Server command line tools image. Initialize repository and keystore, import, export. |
| `docker-compose.yml` | sample configuration for running web app and command line images via docker-compose |
| `.env` | sample environment variables for `docker-compose.yml`. Use Postgres as a repository |
| `docker-compose-mysql.yml` | docker-compose with MySQL/MariaDB for repository |
| `.env-mysql` | sample environment variables for `docker-compose-mysql.yml` |
| `README.md` | this document |
| `resources/` | directory where you put your unzipped JasperReports Server WAR file installer at build time |
| `scripts/` | entrypoints and scripts for images |
|  - `entrypoint.sh` | ENTRYPOINT for a JasperReports Server web app container. Referred to by `Dockerfile` and `Dockerfile-exploded`. 
|  - `entrypoint-cmdline.sh` | ENTRYPOINT for a JasperReports Server command line container. Referred to by `Dockerfile-cmdline`. 
| `kubernetes/` | directory of JasperReports Server Kubernetes configuration |
| `kubernetes/helm/` | directory of JasperReports Server Helm configuration |
|  - `README.md` | JasperReports Server Kubernetes documentation |
| `options/` | directory of optional configurations and customizations for JasperReports Server containers. includes creating a JasperReports Server cluster |
|  - `README.md` | options documentation |
| `platforms/aws/` | directory of optional configurations and customizations for AWS |
|  - `README.md` | AWS documentation |

## Building your JasperReports Server images

There are two images for JasperReports Server container deployments.
- `jasperserver-pro`: JasperReports Server web application
- `jasperserver-pro-cmdline`: Command line tools. Initialize the repository and keystore, export, import.

### Prepare the resources for the images

We need commercial editions of the JasperReports Server WAR file installer in order to build the images.

1. Either:
  - Download a commerical edition of JasperReports Server WAR File installer zip archive from the TIBCO eDelivery site, which is available to TIBCO/Jaspersoft customers.
  - Or build a WAR file installer from the installation of a commercial Jaspersoft bundled installer [Jaspersoft WAR File Installer builder](buildWARFileInstaller)
1. Put the installer zip file to the `resources` directory in the repository structure.
1. Run resources/unpackWARInstaller.sh or unpackWARInstaller.bat. This will create a directory like jasperreports-server-pro-X.X.X-bin. Also unzip jasperreports-server-pro-X.X.X-bin/jasperserver-pro.war into jasperreports-server-pro-X.X.X-bin/jasperserver-pro.

You can do this manually as well.

If you have downloaded the WAR file installer zip to your ~/Downloads directory:

```console
$ unzip -o -q ~/Downloads/TIB_js-jrs_X.X.X_bin.zip -d resources/

$ cd resources/jasperreports-server-pro-X.X.X-bin

$ unzip -o -q jasperserver-pro.war -d jasperserver-pro
```

### docker build time environment variables

These can be passed on the command line with --build-arg, in an env-file, docker-compose.yml, Kubernetes etc.

For the JasperReports Server Web app (WAR):

| Environment Variable Name | Notes |
| ------------ | ------------- |
| `TOMCAT_BASE_IMAGE` | Tomcat Docker image certified for the version of JasperReports Server being deployed. Linux images using apt-get (Debian) or yum (CentOS, Redhat, Corretto/Amazon Linux 2) package managers. Default for 7.5: "tomcat:9.0.31-jdk11-openjdk". |
| `JASPERREPORTS_SERVER_VERSION` | Version number used in file names. Default for JasperReports Server: 7.5.0 | 
| `EXPLODED_INSTALLER_DIRECTORY` | Directory below the Dockerfiles where the WAR file installer has been prepared as above. Default: resources/jasperreports-server-pro-$JASPERREPORTS_SERVER_VERSION-bin
| `HTTP_PORT` | HTTP port Tomcat runs on and .env file should be updated wih correct port number if any non default port is used. Default: "8080" |
| `HTTPS_PORT` | HTTPS port Tomcat runs on and .env file should be updated wih correct port number if any non default port is used. Default: "8443" |
| `JRS_HTTPS_ONLY` | Enables HTTPS-only mode. Default: false. |
|  | A self signed SSL certificate is defined for Tomcat. |
|`DN_HOSTNAME` | Self signed certificate host name. Default: "localhost.localdomain" |
|`KS_PASSWORD` | SSL Keystore password. Default: "changeit" |
|`POSTGRES_JDBC_DRIVER_VERSION` | Default: 42.2.5. If you change this, the new version will be downloaded from https://jdbc.postgresql.org/download.html  |

For the cmdline:

| Environment Variable Name | Notes |
| ------------ | ------------- |
| `JAVA_BASE_IMAGE` | Java Docker image certified for the version of JasperReports Server being deployed.  Linux images using apt-get (Debian) or yum (CentOS, Redhat, Corretto/Amazon Linux 2) package managers. JDK 8 or 11 from https://github.com/docker-library/docs/blob/master/openjdk/README.md#supported-tags-and-respective-dockerfile-links Default openjdk:11.0-slim |
| `JASPERREPORTS_SERVER_VERSION` | Version number used in file names. Default: 7.5.0 | 
| `EXPLODED_INSTALLER_DIRECTORY` | Directory below the Dockerfiles where the WAR file installer has been prepared as above. Default: resources/jasperreports-server-pro-$JASPERREPORTS_SERVER_VERSION-bin
|`POSTGRES_JDBC_DRIVER_VERSION` | Default: 42.2.5. If you change this, the new version will be downloaded from https://jdbc.postgresql.org/download.html  |

### Build the images

`docker build -t jasperserver-pro:7.5.0 .`

`docker build -t jasperserver-pro-cmdline:7.5.0 -f Dockerfile-cmdline .`

# docker run time environment variables

These can be passed on the command line with -e, in an env-file, docker-compose.yml, Kubernetes etc

For the JasperReports Server Web app (WAR):

This image does not create the repository and keystore files. See cmdline below.

| Environment Variable Name | Notes |
------------ | ------------- |
| `DB_TYPE` | valid dbTypes are: postgresql, mysql, sqlserver, oracle, db2. Default: postgresql. |
| `DB_HOST` | database host IP or domain name. Default: postgres |
| `DB_PORT` | database port. Default: default port for the dbType |
| `DB_USER` | database username. Default: postgres |
| `DB_PASSWORD` | database password. Default: postgres |
| `DB_NAME` | JasperReports Server repository schema name in the database. Default: "jasperserver"  | 
| `HTTP_PORT` | HTTP port Tomcat runs on and .env file should be updated wih correct port number if any non default port is used. Default: HTTP_PORT in image |
| `HTTPS_PORT` | HTTPS port Tomcat runs on and .env file should be updated wih correct port number if any non default port is used. Default: HTTPS_PORT in image |
| `JAVA_OPTS` | Command line options passed to Java. Optional. The Java heap size of JasperReports Server is automatically managed to conform to the container size. |  
| `JAVA_MIN_RAM_PERCENTAGE` | Java heap minimum percentage in the container. Default: 33.3% |
| `JAVA_MAX_RAM_PERCENTAGE` | Java heap maximum percentage in the container. Default: 80.0% |
| `JDBC_DRIVER_VERSION` | optional. for non-PostgreSQL databases. Requires a JDBC driver with the required version accessible through a volume. See [Use of Volumes](#jasperreports-server-use-of-volumes)  |
| `POSTGRES_JDBC_DRIVER_VERSION` | optional, Default: 42.2.5. If you change this, the new version will need to be installed by volume as above. See [Use of Volumes](#jasperreports-server-use-of-volumes) | 
| `JRS_DBCONFIG_REGEN` | Forces updates to the repository JNDI database configuration plus the JDBC driver in tomcat/lib. Default: false. |
| `JRS_HTTPS_ONLY` | Enables HTTPS-only mode. Default: false. |
| `KS_PASSWORD` | SSL Keystore password. Default: "changeit". Only used if a keystore is being overridden through a new keystore.  See new keystore addition through volumes below. | 

For the cmdline:

If the `DB_NAME` repository database does not exist in the configured repository database, the cmdline image will create it,

| Environment Variable Name | Notes |
| ------------ | ------------- |
| `DB_TYPE` | valid dbTypes are: postgresql, mysql, sqlserver, oracle, db2. Default: postgresql. |
| `DB_HOST` | database host IP or domain name. Default: postgres |
| `DB_PORT` | database port. Default: default port for the dbType |
| `DB_USER` | database username. Default: postgres |
| `DB_PASSWORD` | database password. Default: postgres |
| `DB_NAME` | JasperReports Server repository schema name in the database. Default: "jasperserver"  | 
| `JAVA_OPTS` | Command line options passed to Java. Optional. The Java heap size of JasperReports Server is automatically managed to conform to the container size. |  
| `JAVA_MIN_RAM_PERCENTAGE` | Java heap minimum percentage in the container. Default: 33.3% |
| `JAVA_MAX_RAM_PERCENTAGE` | Java heap maximum percentage in the container. Default: 80.0% |
| `JDBC_DRIVER_VERSION` | optional. for non-PostgreSQL databases. Requires a JDBC driver with the required version accessible through a volume. See [Use of Volumes](#jasperreports-server-use-of-volumes)  |
| `POSTGRES_JDBC_DRIVER_VERSION` | optional, Default: 42.2.5. If you change this, the new version will need to be installed by volume as above. See [Use of Volumes](#jasperreports-server-use-of-volumes) | 
| `JRS_LOAD_SAMPLES` | Load JasperReports Server samples when creating the database. Default: false |

# Configuring JasperReports Server with volumes

## Using data volumes

JasperReports Server requires the use of [data volumes](https://docs.docker.com/engine/tutorials/dockervolumes/) for managing persistent data and configurations.

See:
- [Volume plugins] https://docs.docker.com/engine/extend/plugins/)
- [Docker volume tips](https://docs.docker.com/engine/tutorials/dockervolumes/#/important-tips-on-using-shared-volumes

for more information.

## JasperReports Server Volumes

Volumes are required to deploy JasperReports Server in containers.

For the JasperReports Server Web app (WAR):

| Description | Path to override in container | Notes |
| ------------ | ------------- | ------------ |
| License | `/usr/local/share/jasperserver-pro/license` | REQUIRED. Path to contain `jasperserver.license` file to use. |
| Encryption keystore files | `/usr/local/share/jasperserver-pro/keystore` | REQUIRED.  .jrsks and .jrsksp files used to encrypt sensitive values. This volume is required for use with JRS 7.5, which will create these files on this volume if they do not exist when initializing the repository database. |
| JasperReports Server customizations | `/usr/local/share/jasperserver-pro/customization` | Zip files. If a zip file contains `install.sh`, it will be unzipped and executed - useful for hotfixes or config changes in the image. Zip files that do not contain `install.sh` will be unzipped into `${CATALINA_HOME}/webapps/jasperserver-pro`. Files are processed in alphabetical order, so duplicate file names within zips can be overridden. |
| Tomcat level customizations | `/usr/local/share/jasperserver-pro/tomcat-customization` | Zip files that are unzipped into `${CATALINA_HOME}`. Files are processed in alphabetical order, so duplicate file names within zips can be overridden. |
| SSL keystore file | `/usr/local/share/jasperserver-pro/ssl-certificate` | .keystore file containing the certificate in this volume will be loaded into /root and Tomcat updated to use it. The keystore password must be set as the KS_PASSWORD environment variable. |
| Additional default_master installation properties | `/usr/local/share/jasperserver-pro/deploy-customization` |  `default_master_additional.properties` file contents appended to default_master.properties. See "To install the WAR file using js-install scripts" in JasperReports Server Installation Guide |
| JDBC driver for the repository database | /usr/src/jasperreports-server/buildomatic/conf_source/db/dbType/jdbc | Override JDBC drivers within the image for the repository. Valid dbTypes are: postgresql, mysql, sqlserver, oracle, db2. Need to set the `JDBC_DRIVER_VERSION` environment variable to the version number of the driver. |
Note: Tomcat and JasperReports server customizations are applied after deploying the JasperReports Server Application in tomcat.


For the cmdline:

| Description | Path to override in container | Notes |
| ------------ | ------------- | ------------ |
| License | `/usr/local/share/jasperserver-pro/license` | REQUIRED. Path to contain `jasperserver.license` file to use. |
| Encryption keystore files | `/usr/local/share/jasperserver-pro/keystore` | REQUIRED.  .jrsks and .jrsksp files used to encrypt sensitive values. This volume is required for use with JRS 7.5, which will create these files on this volume if they do not exist when initializing the database. |
| Additional default_master installation properties | `/usr/local/share/jasperserver-pro/deploy-customization` |  `default_master_additional.properties` file contents appended to default_master.properties. See "To install the WAR file using js-install scripts" in JasperReports Server Installation Guide |
| JDBC driver for the repository database | /usr/src/jasperreports-server/buildomatic/conf_source/db/<dbType>/jdbc | Override JDBC drivers within the image for the repository. Valid dbTypes are: postgresql, mysql, sqlserver, oracle, db2. Need to set the `JDBC_DRIVER_VERSION` environment variable to the version number of the driver. |
| Buildomatic customizations | `/usr/local/share/jasperserver-pro/buildomatic_customization` | Zip files. If a zip file contains `install.sh`, it will be unzipped and executed - useful for hotfixes or config changes in the image. Zip files that do not contain `install.sh` will be unzipped into `${BUILDOMATIC_HOME}`. Files are processed in alphabetical order, so duplicate file names within zips can be overridden. |

## Setting volumes

`docker run -v external_volume:<path to override in container>`

docker-compose

```
   volumes
      - jrs_license:/usr/local/share/jasperserver-pro/license
```

If you update the files in a volume listed above, you will need to restart the container, as these are only processed at container start time.

## Paths to data volumes on Mac and Windows

You can mount a volume to a directory on your local machine.

For example, to access a license on a local directory on Mac:

```console
docker run --name new-jrs -v /<path>/resources/license:/usr/local/share/jasperserver-pro/license \
   -v /<path>/resources/keystore:/usr/local/share/jasperserver-pro/keystore \
  -p 8080:8080 -e DB_HOST=172.17.10.182 -e DB_USER=postgres -e \
  DB_PASSWORD=postgres -d jasperserver-pro:X.X.
```

Volumes in Docker for Windows need to be under the logged in user's User area ie.

```console
      volumes
        - /C/Users/<user>/Documents/License:/usr/local/share/jasperserver-pro/license
```

Windows paths need some help with a Docker Compose environment setting

```console
COMPOSE_CONVERT_WINDOWS_PATHS=1
```

# Initializing the JasperReport Server Repository

Set the dbType and DB_\* environment variables as outlined above. PostgreSQL (default), MySQL, Oracle, SQL Server and DB2 can be configured as repository databases.

The default command of the cmdline container - `init` - will detect whether the repository host exists and can be connected to, and whether the repository database exists in the host, and create them as needed. The `JRS_LOAD_SAMPLES` environment variable can be set to `true` to load the JasperReports Server samples and their underlying databases into the repository database.

Also there is the standalone `init` command for the image that allows you to pre-create the repository database and samples.

```console
docker run --rm 

  --env-file .env -e DB_HOST=jasperserver_pro_repository  
  
  -v /path/to/directoryContainingLicense:/usr/local/share/jasperserver-pro/license
  
  -v /path/to/directoryForKeystores:/usr/local/share/jasperserver-pro/keystore

  --name jasperserver-pro-init 

  jasperserver-pro-cmdline:X.X.X init
```

The JasperReports Server samples can be loaded via the `init` command without setting the `JRS_LOAD_SAMPLES` environment variable. Add `samples` as a parameter to the `init` command as follows:

```console
docker run --rm 

  --env-file .env -e DB_HOST=jasperserver_pro_repository  
  
  -v /path/to/directoryContainingLicense:/usr/local/share/jasperserver-pro/license
  
  -v /path/to/directoryForKeystores:/usr/local/share/jasperserver-pro/keystore

  --name jasperserver-pro-init 

  jasperserver-pro-cmdline:X.X.X init samples
```

## Using a pre-existing database

To run a JasperReports Server container with a pre-existing PostgreSQL instance, execute these commands:

```console
$ docker run --name some-jasperserver-cmdline \
             -e DB_HOST=some-external-host \
             -e DB_USER=username -e DB_PASSWORD=password \
             -v /path/to/directoryContainingLicense:/usr/local/share/jasperserver-pro/license \
             -v /path/to/directoryForKeystores:/usr/local/share/jasperserver-pro/keystore \
             jasperserver-pro-cmdline:X.X.X

$ docker run --name some-jasperserver \
   -p 8080:8080 -e DB_HOST=some-external-host -e DB_USER=username \
   -v /path/to/directoryContainingLicense:/usr/local/share/jasperserver-pro/license \
   -v /path/to/directoryForKeystores:/usr/local/share/jasperserver-pro/keystore \
   -e DB_PASSWORD=password -d jasperserver-pro:X.X.X
```

Where
- `jasperserver-pro-cmdline:X.X.X` is the image name and version tag of the jasperserver-pro-cmdline image you built. This image will be used to create containers.
- `some-jasperserver-cmdline` is the name of the new JasperReports Server cmdline container
- `jasperserver-pro:X.X.X` is the image name and version tag of the jasperserver-pro web application image you built. This image will be used to create containers.
- `some-jasperserver` is the name of the new JasperReports Server web application container
- `some-external-host` is the hostname, fully qualified domain name (FQDN), or IP address of your database server
- `username` and `password` are the user credentials for your repository database server

## Using a database container

Use linking to run JasperReports Server with the repository database in a container.

```console
$ docker run --name some-postgres -e POSTGRES_USER=username -e POSTGRES_PASSWORD=password -d postgres:10

$ docker run --name some-jasperserver-cmdline \
            --link some-postgres:postgres \
             -v /path/to/directoryContainingLicense:/usr/local/share/jasperserver-pro/license \
             -v /path/to/directoryForKeystores:/usr/local/share/jasperserver-pro/keystore \
             -e DB_HOST=some-postgres \
             -e DB_USER=username -e DB_PASSWORD=password \
             jasperserver-pro-cmdline:X.X.X

$ docker run --name some-jasperserver --link some-postgres:postgres \
   -p 8080:8080 -e DB_HOST=some-postgres -e DB_USER=db_username \
   -v /path/to/directoryContainingLicense:/usr/local/share/jasperserver-pro/license \
   -v /path/to/directoryForKeystores:/usr/local/share/jasperserver-pro/keystore \
   -e DB_PASSWORD=db_password -d jasperserver-pro:X.X.
```

Where

- `some-postgres` is the name of your new database container
- `username` and `password` are the user credentials to use for the new PostgreSQL container and JasperReports Server container
- `postgres:10` [PostgreSQL 10](https://hub.docker.com/_/postgres/) is the PostgreSQL image from Docker Hub. This can be replaced with other database types that match the dbType environment variable
- `jasperserver-pro-cmdline:X.X.X` is the image name and version tag of the jasperserver-pro-cmdline image you built. This image will be used to create containers.
- `some-jasperserver-cmdline` is the name of the new JasperReports Server cmdline container
- `jasperserver-pro:X.X.X` is the image name and version tag for your build. This image will be used to create containers
- `some-jasperserver` is the name of the new JasperReports Server container
-  `db_username` and `db_password` are the user credentials for accessing the database server. Database settings should be modified for your setup

# Building and running with docker-compose

`docker-compose.yml` provides a sample [Compose](https://docs.docker.com/compose/compose-file/) implementation of JasperReports Server with PostgreSQL server, configured with volumes for JasperReports Server web application and license, with pre-setup network and mapped ports. There is also a pre-configured `.env` file for use with docker-compose.

To build and run using `docker-compose.yml`, execute the following commands in the root directory of your repository.

```console
$ docker-compose build
$ docker-compose run jasperserver-pro-cmdline
$ docker-compose up -d jasperserver-pro
```

There is also a `.env-mysql` to show how an external MySQL database running on the default 3306 port can be used as a repository.

Note that you should set the amount of memory and CPU that each JasperReports Server container uses. The options below in the `docker-compose.yml` are recommended as starting points, and may need to be increased if the container is under heavy load. The `entrypoint.sh` configures the underlying Java memory settings according to the container memory settings.

```console
    mem_limit: 3g
    mem_reservation: 1g
    cpu_shares: 250
```

# Import and Export

One maintenance aspect of the JasperReports Server is exporting and importing content - reports, domains and other metadata - with the repository. The cmdline image has commands to allow you to run the JasperReports Server image to do imports and export directly to a JasperReports Server repository database, leveraging the JRS command line `js-export` and `js-import` tools, documented in the `JasperReports Server Administration Guide`.

See [Jaspersoft Documentation](https://community.jaspersoft.com/documentation and search for "Administration" in the page to get the latest.

## Exporting to a JasperReports Server repository

1. Create an 'export.properties' file in a directory, with each line containing parameters for individual imports: zip files and/or directories. See the `JasperReports Server Administration Guide` - section: "Exporting from the Command Line" for the options.

```console
# Comment lines are ignored, as are empty line

# Server setting

--output-zip BS-server-settings-export.zip  --include-server-settings

# Repository export

--output-zip Bikeshare-JRS-export.zip --uris /public/Bikeshare_demo

# Repository export

--output-dir some-sub-directory

# Organization export. The organization has to be created before running this import.

--output-zip Bikeshare_org_user_export.zip --organization Bikeshar
```

1. Run the JasperReports Server image with the export command defining and passing into the command in one or more volumes where the `export.properties` is and the exports are to be stored. And do either:

  1. Use existing database running in Docker. Note the network and DB_HOST settings

  ```console
  docker run --rm 

    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/export 

    -v /path/to/a/volume-license:/usr/local/share/jasperserver-pro/license -v /path/to/a/volume-keystore:/usr/local/share/jasperserver-pro/keystore

    --network js-docker_default -e DB_HOST=jasperserver_pro_repository  

    --name jasperserver-pro-export 

    jasperserver-pro-cmdline:X.X.X export /usr/local/share/jasperserver-pro/export
  ```

  1. Use an external repository database. Note the DB_HOST settings

  ```console
  docker run --rm 

    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/import 

    -v /path/to/a/volume-license:/usr/local/share/jasperserver-pro/license -v /path/to/a/volume-keystore:/usr/local/share/jasperserver-pro/keystore

    -e DB_HOST=domain.or.IP.where.repository.database.is  

    --name jasperserver-export 

    jasperserver-pro:X.X.X export /usr/local/share/jasperserver-pro/import
  ```

After an export run, for _each_ volume passed in:
- A sub-directory below the export file is created: `export-YYYY-MM-DD-HH-MM-SS`
- the export.properties file is copied into that sub-directory as `export.properties`.
- the exported files are in that sub-directory
- the log of the export process is in that sub-directory: `export-YYYY-MM-DD-HH-MM-SS.log`

## Importing to a JasperReports Server repositor

1. Create an 'import.properties' file in a directory, with each line containing parameters for individual imports from export zip files and/or directories. See the `JasperReports Server Administration Guide` - section: "Importing from the Command Line" for the options.

```console
# Comment lines are ignored, as are empty lines

# Server setting

--input-zip BS-server-settings-export.zip

# Repository import

--input-zip Bikeshare-JRS-export.zip

# Import from a directory

--input-dir some-sub-directory

# Organization import. Org has to be created before running this import

--input-zip Bikeshare_org_user_export.zip --organization Bikeshar
```

1. Place the ZIP files and/or directories into the same directory as the `import.properties`

1. Run the JasperReports Server image, defining and passing into the command one or more volumes where the import.properties and the exports are stored


And do either:

  1. Use a database instance running in your container environment. Note the network and DB_HOST settings

  ```console
  docker run --rm 

    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/import 

    -v /path/to/a/volume-license:/usr/local/share/jasperserver-pro/license -v /path/to/a/volume-keystore:/usr/local/share/jasperserver-pro/keystore

    --network js-docker_default -e DB_HOST=jasperserver_pro_repository  

    --name jasperserver-pro-import 

    jasperserver-pro:X.X.X import /usr/local/share/jasperserver-pro/import
  ```

  1. Use an external repository database. Note the DB_HOST setting.

  ```console
  docker run --rm 

    -v /path/to/a/volume:/usr/local/share/jasperserver-pro/import 

    -v /path/to/a/volume-license:/usr/local/share/jasperserver-pro/license -v /path/to/a/volume-keystore:/usr/local/share/jasperserver-pro/keystore

    -e DB_HOST=domain.or.IP.where.database.is  

    --name jasperserver-import 

    jasperserver-pro:X.X.X import /usr/local/share/jasperserver-pro/import
  ```

After an import run, for _each_ volume passed in:
- A sub-directory below the import file is created: `import-YYYY-MM-DD-HH-MM-SS`
- the import.properties file is moved into that sub-directory as `import.properties`.
- the log of the import process is in that sub-directory: `import-YYYY-MM-DD-HH-MM-SS.log`

Note that, as of JasperReports 7.2.0 at least, there is no way to import a organization export.zip at the highest level (root) without first creating the organization via the JasperReports Server user interface or REST.

# JasperReports Server container logs

By default, the JasperReports Server log is streamed to the console so default Docker logging can pick that up.

Beyond the console. there are multiple options for log access, aggregation, and management in the Docker ecosystem. The most common options are:

- volumizing log file
- using container logs [logging drivers]https://docs.docker.com/engine/admin/logging/overview/

For the TIBCO JasperReports Server containers, the default `json-file` docker drivers should be sufficient.

In a more complex environment a log collector should be considered. One example is collecting logs on a remote syslog server. See the [logging drivers](https://docs.docker.com/engine/admin/logging/overview/ documentation for more information.

To volumize the JasperReports Server container log, you can create a container for log storage.


```console

$ docker volume create --name some-jasperserver-lo

$ docker run --name some-jasperserver -v 

some-jasperserver-log:/usr/local/tomcat/webapps/jasperserver-pro/WEB-INF/logs 

-p 8080:8080 -e DB_HOST=172.17.10.182 -e DB_USER=postgres 

-e DB_PASSWORD=postgres -d jasperserver-pro:X.X.

```

Where:

- `some-jasperserver-log` is the name of the new data volume for log storage
- `some-jasperserver` is the name of the new JasperReports Server containe
- `jasperserver-pro:X.X.X`  is the image name and version tag for your build. This image will be used to create containers
- Database settings should be modified for your setup


Note that docker containers do not have separate logs. All information is logged via the driver or application. In the case of the JasperReports Server container, the main log is output by Tomcat to the docker-engine via the logging driver, and the application log specific to JasperReports Server is output to `some-jasperserver-log:/usr/local/tomcat/webapps/jasperserver-pro/WEB-INF/logs`


## Logging in to JasperReports Server


After the JasperReports Server container is up, log into it via URL The URL depends upon your installation. The default configuration uses:

```console
http://<domain or IP>:8080/jasperserver-pr

or if running on port 80:

http://<domain or IP>/jasperserver-pr
```


Where:


- localhost is the name or IP address of the computer hosting JasperReports Server
- 8080 is the port number for the Apache Tomcat application server.

If you used a different port when installing your application server, specify its port number instead of 8080


JasperReports Server ships with the following default credentials

- superuser/superuser - System-wide administrato
- jasperadmin/jasperadmin - Administrator for the default organizatio

# Troubleshooting

## Unable to download phantomjs

At build-time Docker fails with an error "403: Forbidden" when downloading phantomjs

```console
2016-09-19 20:54:50 ERROR 403: Forbidden
```

This occurs when the phantomjs binary is temporarily unavailable for download. You can do one of the following: disable the phantomjs download, change the URL, or use a locally-downloaded phantomjs archive. See `Dockerfile` for details. Note that if you had a successful build and the Docker cache has not been invalidated, you do not need to re-download phantomjs on a subsequent build.


## "No route to host" error on a VPN or network with mas

The default Docker network may conflict with your VPN space.

Change to a different CIDR for the Docker network using `--bip`

See the [Docker networking documentation]https://docs.docker.com/v1.8/articles/networking/#docker0

for more information; for Mac, also see:

[Docker issue 25064](#https://github.com/docker/docker/issues/25064)


## `docker volume inspect` returns incorrect paths on MacOS 


Due to the nature of [Docker for Mac]https://docs.docker.com/engine/installation/mac/#/docker-for-mac, `docker volume inspect` returns paths that are relative to the main docker process. You must either access the path in the container, for example:

`/var/lib/docker/volumes/some-jasperserver-license/_data`

or define a volume path instead of a named volume

This also applies to Docker Compose.

See [Using data volumes](#using-data-volumes) for defining a local path

For more information see Docker Community Forums: [Host path of volume]

https://forums.docker.com/t/host-path-of-volume/12277/6


## Connection to repository database fail


The entrypoint.sh tries to connect to the repository database before starting the Server. If there are problems, there will be 5 retries to connect before
stopping the process. You can see the problem in the JasperReports Server container log.

```console

PS C:\Users\user\Documents\GitHub\js-docker> docker run --rm --env-file .env-mysql

--name jrs-init-test -v /C/Users/user/Documents/Docker/buildomatic/mysql/jdbc:/usr/src/jasperreports-server/buildomatic/conf_source/db/mysql/jdbc

jasperserver-pro:X.X.X ini

     [exec] Execute failed: java.io.IOException: Cannot run program "git": error=2, No such file or directory


BUILD FAILED

/usr/src/jasperreports-server/buildomatic/bin/validation.xml:493: The following error occurred while executing this line

/usr/src/jasperreports-server/buildomatic/bin/validation.xml:374: The following error occurred while executing this line

/usr/src/jasperreports-server/buildomatic/conf_source/db/mysql/db.xml:73: The following error occurred while executing this line

/usr/src/jasperreports-server/buildomatic/bin/validation.xml:411: The following error occurred while executing this line

/usr/src/jasperreports-server/buildomatic/bin/validation.xml:468: Invalid username/password combination: [jaspersoftX/jaspersoft]

 Treating problem with JDBC connection as unrecoverable


Total time: 0 second

saw 0 OK connections, not at least 

test_connection returned fai

```

You will need to review the network connection between the Server and the database instance, and review DB_\* environment settings


# Docker documentation

For additional questions regarding docker and docker-compose usage see:

- [docker-engine](https://docs.docker.com/engine/installation) documentation
- [docker-compose](https://docs.docker.com/compose/overview/) documentation


# Copyright

Copyright &copy; 2020. TIBCO Software Inc

This file is subject to the license terms contained in the license file that is distributed with this file.

__

TIBCO, Jaspersoft, and JasperReports are trademarks of registered trademarks of TIBCO Software Inc in the United States and/or other countries.

Docker is a trademark or registered trademark of Docker, Inc. in the United States and/or other countries.
