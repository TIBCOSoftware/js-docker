# TIBCO  JasperReports&reg; Server for Docker

# Table of contents

1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
1. [Installation](#installation)
   1. [Get the JaspeReports Server Docker configuration](#get-the-js-docker-dockerfile-and-supporting-resources)
   1. [Repository structure](#the-installed-repository-structure)
   1. [Get the JasperReports Server WAR file installer](#get-the-jasperreports-server-war-file-installer)
1. [docker build time environment variables](#docker-build-time-environment-variables)
1. [docker run time environment variables](#docker-run-time-environment-variables)
1. [Configuring JasperReports Server with volumes](#configuring-jasperreports-server-with-volumes)
   1. [Using data volumes](#using-data-volumes)
   1. [JasperReports Server use of volumes](#jasperreports-server-use-of-volumes)
   1. [Setting volumes](#setting-volumes)
   1. [Paths to data volumes on Mac and Windows](#paths-to-data-volumes-on-mac-and-windows)
1. [Build and run](#build-and-run)
   1. [Building and running with docker-compose](#building-and-running-with-docker-compose)
   1. [Using a pre-existing PostgreSQL database in Docker](#using-a-pre-existing-postgresql-instance-in-docker)
   1. [Creating a new PostgreSQL database](#creating-a-new-postgresql-database)
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

This distribution includes a sample `Dockerfile` and 
supporting files for
building, configuring, and running
TIBCO JasperReports&reg; Server
in a Docker container.  This sample can be used as is 
or modified to meet the needs of your environment. 
The distribution can be downloaded from 
[https://github.com/TIBCOSoftware/js-docker](#https://github.com/TIBCOSoftware/js-docker).

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
- (*recommended*) [docker-compose](https://docs.docker.com/compose/install) version 1.12 or higher
- (*optional*) [git](https://git-scm.com/downloads)
- (*optional*) TIBCO Jaspersoft&reg; commercial license.
- Contact your sales
representative for information about licensing. If you do not specify a
TIBCO Jaspersoft license, the evaluation license is used.
- (*optional*) Preconfigured PostgreSQL 9 database. If you do not
currently have a PostgreSQL instance, you can create a PostgreSQL container
at build time.

# Installation

## Get the js-docker Dockerfile and supporting resources

Download the js-docker repository as a zip and unzip it, or clone the repository from Github.

To download a zip of js-docker:
- Go to [https://github.com/TIBCOSoftware/js-docker](https://github.com/TIBCOSoftware/js-docker)
- Select Download ZIP on the right hand side of the screen.
![Download ZIP or Clone](js-docker-clone-download.png)

Select Open in Desktop if you have a Git Desktop installed. This will clone the repository for you.
 
If you have the Git command line installed, you can clone the JasperReports Server Docker github repository at 
[https://github.com/TIBCOSoftware/js-docker](#https://github.com/TIBCOSoftware/js-docker):

```console
$ git clone https://github.com/TIBCOSoftware/js-docker
$ cd js-docker
```

## The installed Repository structure

The js-docker github repository contains:

- `Dockerfile` - container build commands
- `docker-compose.yml` - sample configuration for building and running via
docker-compose
- `.env` - sample file with environment variables for docker-compose
- `README.md` - this document
- `resources\` - directory where you put your JasperReports Server zip file
or other files you want to copy to the container
  - `README.md` - short description of `resources` structure
- `scripts\`
  - `entrypoint.sh` - sample runtime configuration for starting and running
JasperReports Server from the shell
- `kubernetes` - directory of JasperReports Server Kubernetes configuration [https://github.com/TIBCOSoftware/js-docker/kubernetes](https://github.com/TIBCOSoftware/js-docker/kubernetes)


## Get the JasperReports Server WAR file installer

Download the JasperReports Server WAR File installer zip archive from the TIBCO eDelivery
or build it from a bundled installer [Jaspersoft Community Wiki article](https://community.jaspersoft.com/wiki/creating-jasperreports-server-war-file-installer-bundled-installer)

Copy the installer zip file to the `resources` directory in the repository structure.
For example, if you have downloaded the zip to your ~/Downloads directory:

```console
$ cp ~/Downloads/TIB_js-jrs_X.X.X_bin.zip resources/
```

# docker build time environment variables
These can be passed on the command line with -e, in an env-file, docker-compose.yml, Kubernetes etc.

Environment Variable Name | Notes |
------------ | ------------- |
`HTTPS_PORT` | Defaults to 8443 |
`HTTP_PORT` | Defaults to 8080. Cannot be overridden |
`JAVA_OPTS` | command line options passed to OpenJDK 8 / Tomcat 9 |
`POSTGRES_JDBC_DRIVER_VERSION` | defaults to 42.2.5. If you change this, the new version will be downloaded from https://jdbc.postgresql.org/download.html |
 | |
 | A self signed SSL certificate is configured for the Tomcat environment. |
`DN_HOSTNAME` | self signed certificate host name. Defaults to "localhost.localdomain" |
`KS_PASSWORD` | default keystore password. Defaults to "changeit" |
`JRS_HTTPS_ONLY` | Enables HTTPS-only mode. Default to false. | 

# docker run time environment variables
These can be passed on the command line with -e, in an env-file, docker-compose.yml, Kubernetes etc.

If the `DB_NAME` repository database does not exist in the configured Postgresql database, entrypoint.sh will create it.

Environment Variable Name | Notes |
------------ | ------------- |
`DB_HOST` | database host IP or domain name. defaults to postgres |
`DB_PORT` | database port. defaults to 5432 |
`DB_USER` | database username. defaults to postgres |
`DB_PASSWORD` | database password. defaults to postgres |
`DB_NAME` | JasperReports Server repository schema name in Postgresql. defaults to jasperserver |
`POSTGRES_JDBC_DRIVER_VERSION` | defaults to 42.2.5. If you change this, the new version will be downloaded from https://jdbc.postgresql.org/download.html |
`JRS_LOAD_SAMPLES` | Load JasperReports Server samples when creating the database. defaults to false | 
 | |
`HTTPS_PORT` | Defaults to 8443 | 
`HTTP_PORT` | Defaults to 8080. Cannot be overridden | 
`JAVA_OPTS` | command line options passed to OpenJDK 8 / Tomcat 9 | 
`JRS_DBCONFIG_REGEN` | Forces updates to the repository JNDI database configuration plus the JDBC driver in tomcat/lib. Defaults to false. |
 | |
 | Only used if a keystore is being overridden through a new keystore.  See new keystore addition through volumes below. |
`KS_PASSWORD` | default keystore password. Defaults to "changeit" |
`JRS_HTTPS_ONLY` | Enables HTTPS-only mode. Default to false. |
 | |
 If you are running Postgresql in a container via docker-compose: | If these variables are not set, PostgreSQL will be launched with no access restrictions. |
`POSTGRES_PASSWORD` | |
`POSTGRES_USER` | |



# Configuring JasperReports Server with volumes

## Using data volumes

Docker, Kubernetes and Docker compose best practices recommend the use of
[data volumes](https://docs.docker.com/engine/tutorials/dockervolumes/) for managing
persistent data and configurations. The type and setup of data volumes depend
on your infrastructure. We provide sensible defaults for a basic
docker installation.

Note that the data in data volumes is not removed with the container and needs
to be removed separately. Changing or sharing data in  the default
data volume while the container is running is not recommended. To share a
volume, use [volume plugins](
https://docs.docker.com/engine/extend/plugins/). See the Docker
[documentation](https://docs.docker.com/engine/tutorials/dockervolumes/#/important-tips-on-using-shared-volumes)
for more information.

## JasperReports Server use of volumes

Description | Path to override in container | Notes |
------------ | ------------- | ------------ |
Complete JasperReports Server web application | `${CATALINA_HOME}/webapps/jasperserver-pro` | The complete JasperReport Server WAR structure in the external volume |
License | `/usr/local/share/jasperreports-pro/license` | Path to contain jasperserver.license file to use. If not provided, a temporary license is used. |
JasperReports Server customizations | `/usr/local/share/jasperreports-pro/customization` | Volume to contain zip files that are unzipped into `${CATALINA_HOME}/webapps/jasperserver-pro`. Files are processed in alphabetical order, so duplicate file names can be overridden. | 
Tomcat level customizations | `/usr/local/share/jasperserver-pro/tomcat-customization` | Volume to contain zip files that are unzipped into `${CATALINA_HOME}`. Files are processed in alphabetical order, so duplicate file names can be overridden. |
New keystore file | `/usr/local/share/jasperserver-pro/keystore` | .keystore files in this volume loaded into /root. The keystore password must be set as the KS_PASSWORD environment variable.|
 Additional default_master installation properties | `/usr/local/share/jasperserver-pro/deploy-customization` |  `default_master_additional.properties` file contents appended to default_master.properties. See "To install the WAR file using js-install scripts" in JasperReports Server Installation Guide |

## Setting volumes

`docker run -v external_volume:<path to override in container>`

docker-compose:

```
   volumes:
      - jrs_license:/usr/local/share/jasperreports-pro/license 
```

If you update the files in a volume listed above, you will need to restart the container, as these are only processed at container start time.

### Paths to data volumes on Mac and Windows

You can mount a volume to a directory on your local machine.
For example, to access a license on a local directory on Mac:

```console
docker run --name new-jrs
-v /<path>/resources/license:/usr/local/share/jasperreports-pro/license 
-p 8080:8080 -e DB_HOST=172.17.10.182 -e DB_USER=postgres -e 
DB_PASSWORD=postgres -d jasperserver-pro:X.X.X
```

Volumes in Docker for Windows need to be under the logged in user's User area ie.

```console
volumes:
	- /C/Users/<user>/Documents/License:/usr/local/share/jasperserver-pro/license 
```

Windows paths need some help with a Docker Compose environment setting:

```console
COMPOSE_CONVERT_WINDOWS_PATHS=1
```

# Build and run

## Building and running with docker-compose

`docker-compose.yml` provides a sample
[Compose](https://docs.docker.com/compose/compose-file/) implementation of
JasperReports Server with PostgreSQL server, configured with volumes for
JasperReports Server web application and license, with pre-setup network and
mapped ports. There is also a pre-configured `.env` file for use with
docker-compose.

To build and run using `docker-compose.yml`, execute the following commands in
the root directory of your repository:

```console
$ docker-compose build
$ docker-compose up -d
```

## Using a pre-existing PostgreSQL database

To build and run a JasperReports Server container with a pre-existing
PostgreSQL instance, execute these commands in your repository:

```console
$ docker build -t jasperserver-pro:X.X.X .
$ docker run --name some-jasperserver -p 8080:8080 \
-e DB_HOST=some-external-postgres -e DB_USER=username \
-e DB_PASSWORD=password -d jasperserver-pro:X.X.X
```

Where:

- `jasperserver-pro:X.X.X` is the image name and version tag
for your build. This image will be used to create containers.
- `some-jasperserver` is the name of the new JasperReports Server container.
- `some-external-postgres` is the hostname, fully qualified domain name
(FQDN), or IP address of your PostgreSQL server.
-  `username` and `password` are the user credentials for your PostgreSQL
server.

## Creating a new PostgreSQL database in Docker

To build and run JasperReports Server with a new PostgreSQL container
you can use linking:

```console
$ docker run --name some-postgres -e POSTGRES_USER=username \
-e POSTGRES_PASSWORD=password -d postgres:10
$ docker build -t jasperserver-pro:X.X.X .
$ docker run --name some-jasperserver --link some-postgres:postgres \
-p 8080:8080 -e DB_HOST=some-postgres -e DB_USER=db_username \
-e DB_PASSWORD=db_password -d jasperserver-pro:X.X.X
```

Where:

- `some-postgres` is the name of your new PostgreSQL container.
- `username` and `password` are the user credentials to use for the
new PostgreSQL container and JasperReports Server container.
- `postgres:10` [PostgreSQL 10](https://hub.docker.com/_/postgres/) is
the PostgreSQL image from Docker Hub.
- `jasperserver-pro:X.X.X` is the image name and version tag
for your build. This image will be used to create containers.
- `some-jasperserver` is the name of the new JasperReports Server container.
-  `db_username` and `db_password` are the user credentials for accessing
the PostgreSQL server. Database settings should be modified for your setup.

The `docker-compose.yml` shows how to launch a PostgreSQL repository automatically.

# JasperReports Server logs

By default, the JasperReports Server log is streamed to the console,
so default Docker logging can pick that up.

Beyond the console. there are multiple options for log access, aggregation, and management
in the Docker ecosystem. The most common options are:

- volumizing log files
- using docker [logging drivers](
https://docs.docker.com/engine/admin/logging/overview/)

For the TIBCO JasperReports Server Docker, the default `json-file`
docker drivers should be sufficient.
In a more complex environment a log collector should be considered. One
example is collecting logs on a remote syslog server.
See the
[logging drivers](https://docs.docker.com/engine/admin/logging/overview/)
documentation for
more information.

To volumize the JasperReports Server container log, you can create a container
for log storage:

```console
$ docker volume create --name some-jasperserver-log
$ docker run --name some-jasperserver -v \
some-jasperserver-log:/usr/local/tomcat/webapps/jasperserver-pro/WEB-INF/logs \
-p 8080:8080 -e DB_HOST=172.17.10.182 -e DB_USER=postgres \
-e DB_PASSWORD=postgres -d jasperserver-pro:X.X.X
```
Where:

- `some-jasperserver-log` is the name of the new data volume for log storage.
- `some-jasperserver` is the name of the new JasperReports Server container
- `jasperserver-pro:X.X.X`  is the image name and version tag.
for your build. This image will be used to create containers.
- Database settings should be modified for your setup.

Note that docker containers do not have separate logs. All information is
logged via the driver or application. In the case of the JasperReports
Server container, the main log is output by Tomcat to the docker-engine
via the logging driver, and the application log specific to
JasperReports Server is output to
`some-jasperserver-log:/usr/local/tomcat/webapps/jasperserver-pro/WEB-INF/logs`

## Logging in to JasperReports Server 

After the JasperReports Server container is up, log into it via URL.
The URL depends upon your installation. The default configuration uses:

```
http://localhost:8080/jasperserver-pro
```

Where:

- localhost is the name or IP address of the computer hosting JasperReports Server.
- 8080 is the port number for the Apache Tomcat application server. 
If you used a different port when installing your application server, 
specify its port number instead of 8080.

JasperReports Server ships with the following default credentials:

- superuser/superuser - System-wide administrator
- jasperadmin/jasperadmin - Administrator for the default organization

# Troubleshooting

## Unable to download phantomjs
At build-time Docker fails with an error "403: Forbidden" when downloading
phantomjs:

```
2016-09-19 20:54:50 ERROR 403: Forbidden.
```

This occurs when the phantomjs binary is temporarily unavailable for download.
You can do one of the following: disable the phantomjs download, change the
URL, or use a locally-downloaded phantomjs archive. See `Dockerfile` for
details. Note that if you had a successful build and the Docker cache has not
been invalidated,
you do not need to re-download phantomjs on a subsequent build.

## "No route to host" error on a VPN or network with mask

The default Docker network may conflict with your VPN space.
Change to a different CIDR for the Docker network using `--bip`.
See the [Docker networking documentation](
https://docs.docker.com/v1.8/articles/networking/#docker0)
for more information; for Mac, also see
[Docker issue 25064](#https://github.com/docker/docker/issues/25064).

## `docker volume inspect` returns incorrect paths on MacOS X

Due to the nature of [Docker for Mac](
https://docs.docker.com/engine/installation/mac/#/docker-for-mac)
 `docker volume inspect` returns paths that are relative to the main docker
process. You must either access the path in the container, for example,
`/var/lib/docker/volumes/some-jasperserver-license/_data`,
or define a volume path instead of a named volume.
This also applies to Docker Compose.
See [Using data volumes](#using-data-volumes) for defining a local path.
For more information see Docker Community Forums: [Host path of volume](
https://forums.docker.com/t/host-path-of-volume/12277/6)

## Connection to repository database fails

The entrypoint.sh tries to connect to the repository database before starting
the Server. If there are problems, there will be 5 retries to connect before
stopping the process. You can see the problem in the JasperReports Server
container log.

```
psql: FATAL:  password authentication failed for user "postgres"
Waiting for PostgreSQL...
psql: FATAL:  password authentication failed for user "postgres"
Waiting for PostgreSQL...
psql: FATAL:  password authentication failed for user "postgres"
Waiting for PostgreSQL...
psql: FATAL:  password authentication failed for user "postgres"
Waiting for PostgreSQL...
psql: FATAL:  password authentication failed for user "postgres"
Waiting for PostgreSQL...
Error: Connection to PostgreSQL on host: jasperserver_pro_repository not available!
```

You will need to review the network connection between the Server and the PostgreSQL
instance and DB_\* environment settings.

# Docker documentation
For additional questions regarding docker and docker-compose usage see:
- [docker-engine](https://docs.docker.com/engine/installation) documentation
- [docker-compose](https://docs.docker.com/compose/overview/) documentation

# Copyright
Copyright &copy; 2019. TIBCO Software Inc.
This file is subject to the license terms contained
in the license file that is distributed with this file.
___

TIBCO, Jaspersoft, and JasperReports are trademarks or
registered trademarks of TIBCO Software Inc.
in the United States and/or other countries.

Docker is a trademark or registered trademark of Docker, Inc.
in the United States and/or other countries.
