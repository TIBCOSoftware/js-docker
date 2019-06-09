# TIBCO JasperReports&reg; Server with Kubernetes

# Table of contents

1. [Introduction](#introduction)
1. [Prerequisites](#prerequisites)
1. [JasperReports Server Image Installation](#jasperreports-server-image-installation)
1. [Configure and Start the Jaspersoft repository database](#configure-and-start-the-jaspersoft-repository-database)
1. [Configure the JasperReports Server service](#configure-the-jasperreports-server-service)
1. [Launch the JasperReports Server service](#launch-the-jasperreports-server-service)
1. [Logging in to JasperReports Server ](#logging-in-to-jasperreports-server)

# Introduction

These configuration files perform
[declarative configuration](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
with `kubectl apply` to deploy JasperReports Server within Kubernetes (k8s).

These Kubernetes configurations leverage images created via [https://github.com/TIBCOSoftware/js-docker](#https://github.com/TIBCOSoftware/js-docker)
and configuration options for the JasperReports Server containers are defined there.

You must change the environment variables and declarative configuration to fit with your deployment environment,
such as the platform - Docker for Windows/Mac, Minikube, Amazon EKS, Azure AKS, ... -
and how you want to deploy JasperReports Server:
- exposed to the outside world directly: NodePort, Ingress, LoadBalancer
- JasperReports Server repository database location: within or external to Kubernetes
- use of environment variables and volumes
- use of secrets for passwords

This configuration has been certified using
the PostgreSQL 9 database with JasperReports Server 6.4+
and with PostgreSQL 10 for JasperReports Server 7.2+.

Knowledge of Docker, Kubernetes and your infrastructure is required.
For more information about Docker see the
[official documentation for Docker](https://docs.docker.com/).

For more information about JasperReports Server, see the
[Jaspersoft community](http://community.jaspersoft.com/).

# Prerequisites

The following software is required or recommended:

- [docker-engine](https://docs.docker.com/engine/installation) version 1.18 or higher
- [kubernetes](https://kubernetes.io/) version 1.10 or higher
- (*Recommended* for development - they include Kubernetes):
  - [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
  - [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)
- (*optional*) [git](https://git-scm.com/downloads)
- (*optional*) TIBCO Jaspersoft&reg; commercial license.
- Contact your sales
representative for information about licensing. If you do not specify a
TIBCO Jaspersoft license, a 3 day evaluation license is used.
- (*optional*) Preconfigured PostgreSQL 9 or 10 database. If you do not
currently have a PostgreSQL instance, you can create a PostgreSQL container
at build time.

# JasperReports Server Image Installation

Build a JasperReports Server image as "jasperserver-pro:X.X.X" as per 
 [https://github.com/TIBCOSoftware/js-docker](https://github.com/TIBCOSoftware/js-docker)
 
Depending on your platform, you may need to push the image into the image repository the platform will use, so Docker/k8s can access it.

# Configure and Start the Jaspersoft repository database

This JasperReports Server deloyment to Docker and k8s uses a PostgreSQL database to store configuration information.

You can run the PostgreSQL repository outside k8s.
- You will need to set the DB_\* environment variables in the k8s configuration to point to the external database.

Or run the PostgreSQL repository inside k8s, which is the default approach taken with this configuration.
- edit `postgres-k8s.yml` to suit your environment.
  - This creates a persistent volume and the `postgresql` service in k8s 
  - set volume name, username, password, use secrets etc according to your requirements
- use kubectl to create the postgresql service: `kubectl apply -f postgres-k8s.yml`

# Configure the JasperReports Server service

Edit the `jasperreports-server-k8s.yml` file.

By default, this is a basic deployment, standing up a single instance service, exposed to the outside world through a NodePort.
It refers to the repository via `DB_HOST`, which in the default configuration is the `postgresql` service within k8s defined above.
- Modify the environment variables as needed: Refer to [JasperReports Server Docker environment variables](https://github.com/TIBCOSoftware/js-docker#docker-run-time-environment-variables)
- Volumes and volume contents that may be needed: [JasperReports Server Docker volumes](https://github.com/TIBCOSoftware/js-docker#configuring-jasperreports-server-with-volumes)
  - License file
  - JasperReports Server WAR level configuration, like single sign on, clustering etc.
- Adjust the DB_\* environment variables to reach the repository.
- Do k8s level configuration, such as pods, LoadBalancer, use of secrets etc.
  - You can set the NodePort the Server will run on or change the network access as you see fit.

# Launch the JasperReports Server service

`kubectl apply -f jasperreports-server-k8s.yml`


# Logging in to JasperReports Server 

After the JasperReports Server container is up, log into it via URL from a browser.

The default JasperReports Server configuration here puts the Server on a public
NodePort of your k8s cluster. Find the assigned port by running:

```
PS > kubectl get services
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
jasperreports-server   NodePort    10.96.1.127    <none>        8080:31562/TCP   3m
kubernetes             ClusterIP   10.96.0.1      <none>        443/TCP          1d
postgresql             ClusterIP   10.100.26.80   <none>        5432/TCP         4m
```

31562 is the NodePort for the jasperreports-server service in the PORT(S) column.

So login via:

```
http://<host>:<NodePort>/jasperserver-pro
```

Where:

- host : name or IP address of your k8s cluster.
- NodePort : NodePort the jasperreports-server service is running on.

JasperReports Server ships with the following default credentials:

- superuser/superuser - System-wide administrator
- jasperadmin/jasperadmin - Administrator for the default organization

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
