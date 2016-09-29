# TIBCO JasperReports Server Docker

-    TBD: links to Dockerfile on github

# Table of contents

1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
  2. [Downloading JasperReports Server](
#downloading-jasperreports-server-war)
  4. [Cloning the repository](#cloning-the-repository)
  1. [Repository structure](#repository-structure)
2. [Build-time environment variables](#build-time-environment-variables)
1. [Build and run](#build-and-run)
  1. [Building and running with docker-compose (recommended)](#compose)
  2. [Building and running with a pre-existing PostgreSQL instance](
#building-and-running-with-a-pre-existing-postgresql-instance)
  1. [Creating a new PostgreSQL instance during build](
#creating-a-new-postgresql-instance-during-build)
1. [Additional configurations](#additional-configurations)
  1. [Runtime variables](#runtime-variables)
  1. [SSL configuration](#ssl-configuration)
  1. [Using data volumes](#using-data-volumes)
  1. [Web application](#web-application)
  1. [License](#license)
  1. [Logging](#logging)
1. [Updating Tomcat](#updating-tomcat)
1. [Customizing JasperReports Server at runtime](
#customizing-jasperreports-server-at-runtime)
1. [Troubleshooting](#troubleshooting)

# Introduction

This distribution includes a `Dockerfile` and supporting files for
building, configuring, and running TIBCO JasperReports Server
in a docker container.
This simple reference configuration  is provided as a starting point
for your own implementation and is not intended for production use.
This configuration is supported by the TIBCO Jaspersoft Community.
TIBCO Jaspersoft Technical Support and Engineering do not support it.

This configuration has been certified using
the PostgreSQL 9.4 database with JasperReports Server 6.3.0.

Basic knowledge of Docker and the underlying infrastructure is required.
For more information about Docker see the
[official documentation for Docker](https://docs.docker.com/).

For more information about JasperReports Server, see the
[Jaspersoft community](http://community.jaspersoft.com/).

# Prerequisites

The following software is required or recommended:

- [docker-engine](https://docs.docker.com/engine/installation) version 1.12 or
higher
- (*recommended*) [docker-compose](https://docs.docker.com/compose/install)
version 1.12 or higher
- [git](https://git-scm.com/downloads)
- (*optional*) TIBCO Jaspersoft commercial license. Contact your sales
representative
for information about licensing. If you do not specify a TIBCO Jaspersoft
license, the evaluation license is used.
- (*optional*) Preconfigured PostgreSQL 9.4 database. If you do not
currently have a PostgreSQL instance, you can create a PostgreSQL container
at build time.

## Downloading JasperReports Server WAR

Download the JasperReports Server commercial zip archive from the Support
Portal and copy it to the `resources` directory of your archive. For example,
if you have downloaded the archive to your ~/Downloads directory:

```console
$ cp ~/Downloads/jasperreports-server-6.3.0-bin.zip resources/
```

## Cloning the repository

Clone the JasperReports Server Docker github repository at TBD:

```console
$ git clone ...
$ cd jrs-docker
```

## Repository structure

When you clone the github repository, the following files are placed
on your machine:

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

# Build-time environment variables
At build time, JasperReports Server uses the following environment variables.
These variables can be set directly in the `Dockerfile`.
In addition, if you are using docker-compose, many of these variables
can be set in the `docker-compose.yml` or the `.env` file.
See the
[Compose file reference](https://docs.docker.com/compose/compose-file/#/args)
for more information:

- `DB_USER` - database username
- `DB_PASSWORD` - database password
- `DB_HOST` - database host
- `DB_PORT` - database port
- `DB_NAME` - JasperReports Server database name
- `JRS_DBCONFIG_REGEN` - When true, forces database configuration regeneration
on container run. This variable can be used to point an already existing
JasperReports Server container to a new PostgreSQL server.
- `JRS_HTTPS_ONLY` - When true, enables HTTPS-only mode.
HTTPS-only requires modifications to the
`Dockerfile`; see [SSL configuration](ssl-configuration)
and the comments in the `Dockerfile` for details.
Note that `JRS_HTTP_ONLY` must be set directly in the `Dockerfile`,
because it requires additional configuration.

[Compose](https://docs.docker.com/compose) requires
the following additional variables to set up the generated PostgreSQL
container.
If these variables are not set, PostgreSQL will be generated with no access
restrictions.

- `POSTGRES_USER`
- `POSTGRES_PASSWORD`

# Build and run

## <a name="compose"></a>Building and running with docker-compose (recommended)

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
$ docker-compose up
```

## Building and running with a pre-existing PostgreSQL instance

To build and run a JasperReports Server container with a pre-existing
PostgreSQL 9.4 instance, execute these commands in your repository:

```console
$ docker build -t jasperserver-pro:6.3.0 .
$ docker run --name some-jaserserver -p 8080:8080 \
-e DB_HOST=some-external-postgres -e DB_USER=username \
-e DB_PASSWORD=password -d jasperserver-pro:6.3.0
```

Where:

- `jasperserver-pro:6.3.0` is the image name and version tag
for your build. This image will be used to create containers.
- `some-jasperserver` is the name of the new JasperReports Server container.
- `some-external-postgres` is the hostname, fully qualified domain name
(FQDN), or IP address of your PostgreSQL server.
-  `username` and `password` are the user credentials for your PostgreSQL
server.

## Creating a new PostgreSQL instance during build

To build and run JasperReports Server with a new PostgreSQL container
you can use linking:

```console
$ docker run --name some-postgres -e POSTGRES_USER=username \
-e POSTGRES_PASSWORD=password -d postgres:9.4
$ docker build -t jasperserver-pro:6.3.0 .
$ docker run --name some-jasperserver --link some-postgres:postgres \
-p 8080:8080 -e DB_HOST=some-postgres -e DB_USER=db_username \
-e DB_PASSWORD=db_password -d jasperserver-pro:6.3.0
```

Where:

- `some-postgres` is the name of your new PostgreSQL container.
- `username` and `password` are the user credentials to use for the
new PostgreSQL container and JasperReports Server container.
- `postgres:9.4` [PostgreSQL 9.4](https://hub.docker.com/_/postgres/) is
the PostgreSQL image from Docker Hub.
- `jasperserver-pro:6.3.0` is the image name and version tag
for your build. This image will be used to create containers.
- `some-jasperserver` is the name of the new JasperReports Server container.
-  `db_username` and `db_password` are the user credentials for accessing
the PostgreSQL server.

# Additional configurations

## Runtime variables
Runtime variables are set to sensible defaults and in general do not
require changes. However you can change them, for example,  to adjust
Java options for running the JasperReports Server container.
See the `Dockerfile` for pre-defined environment variables.

## SSL configuration
To enable generation and configuration of a self-signed certificate for the
JasperReports Server container at build time:

- Locate and uncomment the SSL section in the `Dockerfile`.
This commented section
contains `ENV` and `RUN` commands to set up variables for
key dname, keystore password, `HTTPS_PORT` and HTTPS-only mode
for JasperReports Server.
- Run `keytool` to generate a new key and keystore.
- Edit your Tomcat configuration to use the new keystore by default.

## Using data volumes

Docker recommends the use of [data volumes](
https://docs.docker.com/engine/tutorials/dockervolumes/) for managing
persistent data and configurations. The type and setup of data volumes depend
on your infrastructure. We provide sensible defaults for a basic
docker installation.
Data volumes are also enabled by default in `docker-compose.yml`, see
[Building and running with docker-compose](#compose)
for more information.

Note that the data in data volumes is not removed with the container and needs
to be removed separately. Changing or sharing data in  the default
data volume while the container is running is not recommended. To share a
volume, use [volume plugins](
https://docs.docker.com/engine/extend/plugins/). See the Docker
[documentation](https://docs.docker.com/engine/tutorials/dockervolumes/#/
important-tips-on-using-shared-volumes) for more information.

## Web application

By default, the JasperReports Server Docker container stores the web
application data in /usr/local/tomcat/webapps/jasperserver-pro. To create a
locally-accessible named volume, run the following commands at container
generation time:
```console
$ docker volume create --name some-jasperserver-data
$ docker run --name some-jasperserver \
-v some-jasperserver-data:/usr/local/tomcat/webapps/jasperserver-pro \
jasperserver-pro:6.3.0
```
Where:

- `some-jasperserver-data` is the name of the new data volume.
- `some-jasperserver` is the name of the new JasperReports Server container.
- `jasperserver-pro:6.3.0`  is the image name and version tag
for your build. This image will be used to create containers.

Now you can access the JasperReports Server web application
locally. Run `docker inspect volume jasperserver-data` to determine the storage
path and additional details about the new volume.

If you want to define the local volume path manually, you cannot use named
volumes. Instead, modify `docker run` like this:
```console
$ docker run --name some-jasperserver -v \
/some-path/some-jasperserver-data:/usr/local/tomcat/webapps/jasperserver-pro \
jasperserver-pro:6.3.0
```
Where:
- `/some-path/some-jasperserver-data` is a local path that will be mounted.

## License

By default, the JasperReports Server Docker container expects to find the
license in the
`/usr/local/share/jasperreports-pro/license` directory on your system.
If a license file
is not present at this location, then the 30-day evaluation license is used.

You can add a license volume and store your commercial license there, for
example:

```console
$ docker volume create --name some-jasperserver-license
$ sudo cp jasperserver.license \
/var/lib/docker/volumes/some-jasperserver-license/_data
$ docker run --name some-jasperserver \
-v some-jasperserver-license:/usr/local/share/jasperreports-pro/license \
-d jasperserver-pro:6.3.0
```
Where:

- `some-jasperserver-license` is the name of the new data volume.
- `/var/lib/docker/volumes/some-jasperserver-license/_data` is an example path.
It may differ on your system, use `docker volume inspect` to get
local path to volume.
- `some-jasperserver` is the name of the new JasperReports Server container
- `jasperserver-pro:6.3.0`  is the image name and version tag
for your build. This image will be used to create containers.

See `Dockerfile` and `scripts/entrypoint.sh` for details.

To update your license without data volumes on an existing container:

```console
$ docker cp jasperserver.license \
some-jasperserver:/usr/local/share/jasperreports-pro/license/
$ docker restart some-jasperserver
```
Where:

- `some-jasperserver` is the name of the new JasperReports Server container.

Note that you need to stop the JasperReports Server container
prior to license update and restart it after.
# Logging

There are multiple options for log access, aggregation, and management
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
-d jasperserver-pro:6.3.0
```
Where:

- `some-jasperserver-log` is the name of the new data volume for log storage.
- `some-jasperserver` is the name of the new JasperReports Server container
- `jasperserver-pro:6.3.0`  is the image name and version tag.
for your build. This image will be used to create containers.

Note that docker containers do not have separate logs. All information is
logged via the driver or application. In the case of the JasperReports
Server container, the main log is output by Tomcat to the docker-engine
via the logging driver, and the application log specific to
JasperReports Server is output to
`some-jasperserver-log:/usr/local/tomcat/webapps/jasperserver-pro/WEB-INF/logs`

# Updating Tomcat

The JasperReports Server container is based on the
[tomcat:8.0-jre8](tomcat:8.0-jre8) (Apache Tomcat) image from
[Docker Hub](https://hub.docker.com).
To upgrade your JasperReports Server base image, you
must rebuild the JasperReports Server image with the newer Tomcat. See
[Build and run](#build-and-run) for building instructions.

To update an already existing JasperReports Server container to
a newer base image, you have to re-create it. If you are using volumes
for JasperReports Server, you can preserve web application data between
upgrades.
This can be useful if you have
[customizations or configuration](#customizing-jasperreports-server-at-runtime)
changes applied to
the default web application:

```console
$ docker stop some-jasperserver
$ docker run --name some-jasperserver-2 -v \
some-jasperserver-data:/usr/local/tomcat/webapps/jasperserver-pro \
-d jasperserver-pro:6.3.0
```
Where:

- `some-jasperserver` is the name of the existing JasperReports Server
container.
- `some-jasperserver-2` is the name of the new JasperReports Server container.
- `some-jasperserver-data` is the name of a data volume.
- `jasperserver-pro:6.3.0` is an image name and version tag that is used
as a base for the new container.

# Customizing JasperReports Server at runtime

Customizations can be added to JasperReports Server container at runtime
via the `/usr/local/share/jasperreports-pro/customization` directory in the
container. All zip files in this directory are applied to
`/usr/local/tomcat/webapps/jasperserver-pro` in sorted order (natural sort).
This directory can be also mounted as a [Data Volume](
https://docs.docker.com/engine/tutorials/dockervolumes/).

For example:
```console
$ docker volume create --name some-jasperserver-customization
$ sudo cp custom.zip \
/var/lib/docker/volumes/some-jasperserver-customization/_data
$ docker run --name some-jasperserver -v \
some-jasperserver-customization:\
/usr/local/share/jasperreports-pro/customization \
-d jasperserver-pro:6.3.0
```
Where:

- `some-jasperserver-customization` is the name of the customization
data volume.
- `custom.zip` is an archive containing customizations, for example:
`WEB-INF/log4j.properties`. The archive will be unpacked as-is to the path
`/usr/local/tomcat/webapps/jasperserver-pro`
- `/var/lib/docker/volumes/some-jasperserver-customization/_data` is an
example path. Use `docker volume inspect`
to get the local path to the volume for your system.
- `some-jasperserver` is the name of the JasperReports Server
container.
- `jasperserver-pro:6.3.0` is an image name and version tag that is used
as a base for the new container.

See `scripts/entrypoint.sh` for implementation details and
`docker-compose.yml` for a sample setup of a customization volume via Compose.

You can also apply customizations manually, either via the `docker cp` command
or by modifying files in the [web application](#web-application) data volume.
For example:
```console
$ docker cp log4j.properties some-jasperserver:\
/usr/local/tomcat/webapps/jasperserver-pro/WEB-INF/
$ docker restart some-jasperserver
```
Where:

- `some-jasperserver` is the name of the JasperReports Server
container.

Note that independent of method, you need to restart the
JasperReports Server container (`docker restart some-jasperserver`)
if customizations are applied to a running container.

# Troubleshooting
- At build-time Docker fails with an error "403: Forbidden" when downloading
phantomjs:
```
2016-09-19 20:54:50 ERROR 403: Forbidden.
```
This occurs when the phantomjs binary is temporarily  unavailable for download.
You can do one of the following: disable the phantomjs download, change the
URL, or use a locally-downloaded phantomjs archive. See `Dockerfile` for
details. Note that if you had a successful build and the Docker cache has not
been invalidated,
you do not need to re-download phantomjs on a subsequent build.
- "No route to host" error on  a VPN/network with mask.
The default Docker network may conflict with your VPN space.
Change to a different CIDR for the Docker network using `--bip`.
See the [Docker networking documentation](
#https://docs.docker.com/v1.8/articles/networking/#docker0)
for more information; for Mac, also see
[Docker issue 25064](#https://github.com/docker/docker/issues/25064).
- `docker volume inspect` returns incorrect paths on MacOS X.
Due to the nature of [Docker for Mac](
https://docs.docker.com/engine/installation/mac/#/docker-for-mac)
 `docker volume inspect` returns paths that are relative to the main docker
process. You must either access the path in the container, for example,
`/var/lib/docker/volumes/some-jasperserver-license/_data`,
or define a volume path instead of a named volume.
Same applies to Docker Compose.
See [Using data volumes](#using-data-volumes) for defining a local path.
For more information see Docker Community Forums: [Host path of volume](
https://forums.docker.com/t/host-path-of-volume/12277/6)

# Copyright
Copyright &copy; 2005 - 2016. TIBCO Software Inc. All Rights Reserved.

Document version number: 0916-JSP64-01
