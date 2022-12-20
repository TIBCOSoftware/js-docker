


<details>
<summary>Table of Contents</summary>
<!-- TOC -->
  
- [Introduction](#introduction) 
  - [Prerequisites](#prerequisites)
  - [Parameters](#parameters)
  - [Adding External Helm Repositories](#adding-external-helm-repositories)
- [Installing TIBCO JasperReports® Server](#installing-tibco-jasperreports-server)
  - [JMS Configuration](#jms-configuration)
  - [Ingress Controller](#ingress-controller)
  - [Monitoring](#monitoring)
  - [Logging](#logging)
  - [Repository DB Does Not Exist](#repository-db-does-not-exist)
  - [Repository DB Already Exists](#repository-db-already-exists)
  - [Verifying installation](#verifying-installation)
- [EKS Configuration](#eks-configuration)
  - [Prerequisites](#prerequisites)
  - [Installation Procedure](#installation-procedure)
- [Integrating the Scalable Query Engine and JasperReports Server](#integrating-the-scalable-query-engine-and-jasperreports-server)
- [Use Case: Deploying TIBCO JasperReports® Server Using PostgreSQL Container in K8s Cluster](#use-case-deploying-tibco-jasperreports-server-using-postgresql-container-in-k8s-cluster)
  - [Installation](#installation-1)
 - [Troubleshooting](#troubleshooting)
  <!-- /TOC -->
  </details>
  
  
# Introduction
  This helm chart is used to install TIBCO JasperReports® Server in Kubernetes and integrate it with the Scalable Query Engine. 

# Prerequisites
1. Docker-engine (19.x+) setup with Docker Compose  (3.9+)
1. K8s cluster with 1.19+
1. TIBCO JasperReports® Server
1. Keystore 
1. Git
1. [Helm 3.5](https://helm.sh/docs/intro/)
1. [kubectl commandline tool](https://kubernetes.io/docs/tasks/tools/)   
1. Minimum Knowledge of Docker and K8s

# Parameters

These parameters and values are the same as parameters in values.yaml.

| Parameter| Description | default Value |
|------------| -------------| ----------|
| replicaCount| Number of pods | 1 (It will not come into effect if autoscaling is enabled.)| 
| jrsVersion|TIBCO JasperReports® Server release version | 8.0.3 | 
| image.tag | Name of the TIBCO JasperReports® Server webapp image tag | TIBCO JasperReports® Server Release Version|
| image.name| Name of the TIBCO JasperReports® Server webapp image | null|
| image.pullPolicy| Docker image pull policy  | IfNotPresent|
| image.PullSecrets | Name of the image pull secret | Pull secret should be created manually before using it in same namespace, [See Docs](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) |
| nameOverride| Override the default helm chart name  | jasperserver-pro |
| fullnameOverride| Override the default full chart name | Override the full name |
| secretKeyStoreName| Name of the keystore secret | jasperserver-keystore|
| secretLicenseName | Name of the license secret | jasperserver-license|
| serviceAccount.enabled | Service account for TIBCO JasperReports® Server webapp | true |
| serviceAccount.annotations | Adds new annotations | null |
| serviceAccount.name | Name of the service account | jasperserver-pro |
| rbac.create | Creates role and role binding | true |
| rbac.name | Name of the TIBCO JasperReports® Server role and role binding | jasperserver-role |
| podAnnotations | Adds pod annotations | null |
| securityContext.capabilities.drop | Drops Linux capabilites for the TIBCO JasperReports® Server webapp  | All |
| securityContext.runAsNonRoot | Runs the TIBCO JasperReports® Server webapp as non root user | true |
| securityContext.runAsUser | User id to run the TIBCO JasperReports® Server webapp | 10099 |
| buildomatic.enabled | Installs or skips the TIBCO JasperReports® Server repository DB | true|
| buildomatic.name | Name of the TIBCO JasperReports® Server command line tool | jasperserver-buildomatic|
| buildomatic.imageTag| Buildomatic image tag | Same as TIBCO JasperReports® Server release version|
| buildomatic.imageName | Name of the buildomatic image | null|
| buildomatic.pullPolicy | Image pull policy| IfNotPresent|
| buildomatic.PullSecrets | Image pull secrets | null|
| buildomatic.includeSamples| Installs TIBCO JasperReports® Server samples in JasperReports Server DB | true|
| db.env | Enables the DB configuration using environment variables | true |
| db.jrs.dbHost | JasperReports Server repository DB host | repository-postgresql.default.svc.cluster.local |
| db.jrs.dbPort | JasperReports Server repository DB port | 5432|
| db.jrs.dbName | JasperReports Server repository DB name | jasperserver |
| db.jrs.dbUserName | JasperReports Server repository DB user name | postgres |
| db.jrs.dbPassword | JasperReports Server repository DB password | postgres |
| db.audit.dbHost | JasperReports Server audit DB host | repository-postgresql.default.svc.cluster.local |
| db.audit.dbPort | JasperReports Server audit DB port | 5432|
| db.audit.dbName | JasperReports Server audit DB name | jasperserver |
| db.audit.dbUserName | JasperReports Server audit DB user name | postgres |
| db.audit.dbPassword | JasperReports Server audit DB password | postgres |
| extraEnv.javaopts | Adds all JAVA_OPTS  | -XX:+UseContainerSupport -XX:MinRAMPercentage=33.0 -XX:MaxRAMPercentage=75.0 |
| extraEnv.normal | Adds all the normal key value pair variables | null |
| extraEnv.secrets | Adds all the environment references from secrets or configmaps| null | 
| extraVolumeMounts | Adds extra volume mounts | null|
| extraVolumes | Adds extra volumes | null |
| Service.type | TIBCO JasperReports® Server service type | ClusterIP (for now, we kept as NodePort for internal testing)
| Service.port | Service port | 80 |
| healthcheck.enabled | Checks TIBCO JasperReports® Server pod health status | true |
| healthcheck.livenessProbe.port | TIBCO JasperReports® Server container port  | 8080 |
| healthcheck.livenessProbe.initialDelaySeconds | Initial waiting time to check the health and restarts the TIBCO JasperReports® Server Webapp pod | 350 |
| healthcheck.livenessProbe.failureThreshold | Threshold for health checks | 10 |
| healthcheck.livenessProbe.periodSeconds |Time period to check the health | 10 |
| healthcheck.livenessProbe.timeoutSeconds | Timeout | 4 |
| healthcheck.readinessProbe.port | TIBCO JasperReports® Server container port | 8080 |
| healthcheck.readinessProbe.initialDelaySeconds | Initial delay before checking the health checks | 90 |
| healthcheck.readinessProbe.failureThreshold | Threshold for health checks | 15 |
| healthcheck.readinessProbe.periodSeconds | Time period to check the health checks | 10 |
| healthcheck.readinessProbe.timeoutSeconds | Timeout | 4 |
| resources.enabled | Enables the minimum and maximum resources used by TIBCO JasperReports® Server | true |
| resources.limits.cpu | Maximum CPU  | "3" |
| resources.limits.memory | Maximum Memory | 7.5Gi |
| resources.requests.cpu | Minimum CPU | "2" |
| resources.requests.memory | Minimum Memory | 3.5Gi |
| jms.enabled | Enables the ActiveMQ cache service | true|
| jms.jmsBrokerUrl |  | null|
| jms.name | Name of the JMS | jasperserver-cache|
| jms.serviceName | Name of the JMS Service | jasperserver-cache-service |
| jms.imageName | Name of the Activemq image | bansamadev/activemq |
| jms.imageTag | Activemq image tag | 5.17.2 |
| jms.healthcheck.enabled |  | true |
| jms.healthcheck.livenessProbe.port | Container port | 61616 |
| jms.healthcheck.livenessProbe.initialDelaySeconds | Initial delay  | 100 |
| jms.healthcheck.livenessProbe.failureThreshold | Threshold for health check | 10 |
| jms.healthcheck.livenessProbe.periodSeconds | Time period for health check | 10 |
| jms.healthcheck.readinessProbe.port | Container port | 61616 |
| jms.healthcheck.readinessProbe.initialDelaySeconds | Initial delay  | 10 |
| jms.healthcheck.readinessProbe.failureThreshold | Threshold for health check | 15 |
| jms.healthcheck.readinessProbe.periodSeconds | Time period for health check | 10 |
| jms.securityContext.capabilities.drop | Linux capabilities to drop for the pod  | All |
| ingress.enabled | Work with multiple pods and stickyness | false|
| ingress.annotations.ingress.kubernetes.io\/cookie-persistence|  | "JRS_COOKIE"|
| ingress.hosts.host | Adds valid DNS hostname to access the TIBCO JasperReports® Server | null|
| ingress.tls | Adds TLS secret name to allow secure traffic | null| 
| scalableQueryEngine.enabled | Communicates with Scalable Query Engine | false|
| scalable-query-engine.replicaCount | Number of pods for Scalable Query Engine | 2|
| scalable-query-engine.image.tag | Scalable Query Engine image tag | 8.0.3|
| scalable-query-engine.image.name | Name of the Scalable Query Engine image | null |
| scalable-query-engine.image.pullPolicy| Scalable Query Engine image pull policy | ifNotPresent |
| scalable-query-engine.autoscaling.enabled | Enables the HPA for Scalable Query Engine | false |
| scalable-query-engine.drivers.image.tag | Scalable Query Engine image tag | 8.0.3 |
| scalable-query-engine.drivers.image.name |  | null |
| scalable-query-engine.drivers.storageClassName |   | hostpath |
| scalable-query-engine.kubernetes-ingress.controller.service.type |  | ClusterIP |
| autoscaling.enabled | Scales the JasperReports Server application,  **Note:** Make sure metric server is installed or metrics are enabled | false |
| autoscaling.minReplicas | Minimum number of pods maintained by autoscaler | 1 |
| autoscaling.maxReplicas | Maximum number of pods maintained by autoscaler | 4 |
| autoscaling.targetCPUUtilizationPercentage | Minimum CPU utilization to scale up the application | 50% |
| autoscaling.targetMemoryUtilizationPercentage | Minimum memory utilization to scale up the TIBCO JasperReports® Server applications | 50% |
| metrics.enabled | Enables the metrics to display all the metrics | false |
| kube-prometheus-stack.prometheus-node-exporter.hostRootFsMount |  | false |
| kube-prometheus-stack.grafana.service.type | Grafana service type  | NodePort |
| logging.enabled | Enables the centralized logging setup | false |
| elasticsearch.volumeClaimTemplate.resources.requests.storage |  | 10Gi |
| kibana.service.type | Kibana service type | NodePort |
| elasticsearch.replicas | Number of replicas for Elasticsearch  | 1 |
| tolerations | Adds the tolerations as per K8s standard if needed | null |
| affinity | Adds the affinity as per K8s standards if needed | null |

# Adding External Helm Repositories
    
    helm repo add haproxytech https://haproxytech.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add elastic https://helm.elastic.co


# Installing TIBCO JasperReports® Server

1. Go to `jaspersersoft-containers/K8s`, and to update the dependency charts, run `helm dependencies update jrs/helm`.
2. Update the default_master.properties in `Docker/jrs/resources/default_properties` as needed.
3. (Optional , in case DB has to be configure using env variables)Update the `db` section in `values.yaml` with the actual JasperReports Server DB details or create a separate secret like below.
   

      
          apiVersion: v1
          kind: Secret
          type: Opaque
          metadata:
            name: jasperserver-pro-db-secret
            labels:
          data:
            DB_HOST: host-name
            DB_PORT: port-name
            DB_NAME: db-name
            DB_USER_NAME:db-user-name
            DB_PASSWORD:  db-password

All the DB details should be encoded in base64 format. 

   **Note:** By default, the below details are used and for this, DB should be part of OpenShift Cluster in the default project. Please note the  DB is already created, adding this won't enforce to create a DB
 If JasperReports Server is deployed in a different project, then change the dbHost in the following format: `respository-postgresql.<namespace>.svc.cluster.local`.
   

       dbHost: repository-postgresql.default.svc.cluster.local
       dbPort: 5432
       dbName: jasperserver
       dbUserName: postgres
       dbPassword: postgres

These details are stored in Kubernetes secrets and used as environment variables during application startup.

**Note on Audit DB:** Enable the `db.audit.enable=true` if separate Audit DB is required for audit events, and add the below values to the db-secrets. Please note the Audit DB is already created, adding this won't enforce to create a DB


      AUDIT_DB_HOST: audit-db-host
      AUDIT_DB_PORT:  audit-db-port
      AUDIT_DB_NAME:  audit-db-name
      AUDIT_DB_USER_NAME: audit-db-user-name
      AUDIT_DB_PASSWORD: audit-password

4. Build the docker images for TIBCO JasperReports® Server, and Scalable Query Engine (see the [Docker JasperReports Server readme](../../Docker/jrs#readme) and [Docker Scalable Query Engine readme](../../Docker/scalableQueryEngine#readme) ).
5. Generate the keystore and copy it to the `OpenShift/jrs/helm/secrets/keystore` folder, see here for [Keystore Generation ](../../Docker/jrs#keystore-generation).
6. Copy the TIBCO JasperReports® Server license to the `OpenShift/jrs/helm/secrets/license` folder.

## JMS Configuration
  By default, TIBCO JasperReports® Server will install using activemq docker image. You can disable it by changing the parameter `jms.enabled=false`. 
 
 External JMS instance can also be used instead of in-build JMS setup by adding the external jms url `jms.jmsBrokerUrl`. You can access it by using tcp port, for instance `tcp://<JMS-URL>:61616`.

## Ingress Controller

You can use HA Proxy ingress controller to manage the traffic across the TIBCO JasperReports® Server pods.

**Note:** Enable the ingress controller so that TIBCO JasperReports® Server can work with multiple pods.

To enable this setup, run the following command.

    set ingress.enabled: true in values.yaml OR
    pass --set ingress.enabled=true into helm install command

If you want to add or change some properties in ingress, you can do so at kubernetes-ingress and jasperserver config-ingress part in values.yaml. For more information, visit [official documentation](https://github.com/haproxytech/helm-charts)

## Monitoring
**Optional**
- Enable the monitoring by changing the **metric.enabled** parameter, it will install and configure prometheus operator and grafana for visualization. 

- Get the Grafana password by running the below command. The default password is prom-operator.

 ``kubectl get secret --namespace <namespace> <grafana-secret> -o jsonpath="{.data.admin-password}" | base64 --decode ; echo``
 
- Get the Grafana Node port by listing the services and connect the Grafana by using ``HOST_NAME:NODE_PORT `` and username/password: admin/prom-operator.

For more information and configuration, see the [Official Docs](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack).

## Logging
**Optional**
- Enable the centralized logging by changing **logging.enabled**. Elasticsearch, Kibana, and Fluentd (EFK) stack is used for logging.

Elasticsearch and Kibana charts are added as a dependency in the main chart and any modifications to parameters can be done in values.yaml

- To access kibana dashboard while using cluster ip as service type, run the following command.
  `` HOST_NAME:NODE_PORT ``

For more information and configuration, see the [Official Docs](https://github.com/elastic/helm-charts)

**Note:** If any changes are done in the Elasticsearch chart for cluster name and port then the same must be updated accordingly for Fluentd.

## Repository DB Does Not Exist

-  To set up the Repository DB in K8s cluster, run the below command. For this, we are using bitnami/postgresql Helm chart. See the [Official Docs](https://artifacthub.io/packages/helm/bitnami/postgresql) to configure the DB in cluster mode.

`helm install repository bitnami/postgresql --set postgresqlPassword=postgres  --version 11.9.13 --namespace jrs --create-namespace`


- Check the pods status and make sure pods are in a running state.

- If Namespace already exists, remove `--create-namespace` parameter.

- Go to `jaspersoft-containers/k8s` and update the jrs/helm/values.yaml, see the [Parameter](#parameters) section for more information.
  
- Set **buildomatic.enabled=true** for repository setup. By default samples are included, if it is not required, set **buildomatic.includeSamples=false**

- Run the below command to install TIBCO JasperReports® Server and repository setup. 

`helm install jrs jrs/helm --namespace jrs --wait --timeout 17m0s`

**Note:** If Repository Setup fails in the middle then increase the timeout. 

## Repository DB Already Exists

``helm install jrs jrs/helm --namespace jrs --create-namespace``


## Verifying installation
After `helm install` is finished you can verify installed TIBCO JasperReports® Server cluster. 

- Switch to jrs namespace. 

``kubectl config set-context --current --namespace=jrs``

List all the resources.

`` kubectl get all ``  


# EKS Configuration
 
 ## Prerequisites
  1. EKS cluster with cluster auto scaler, [see the docs](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html) to set up a cluster.
  1. Enable the container insights for logging and monitoring, [see the docs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/deploy-container-insights-EKS.html) for enabling the container insights.

## Installation
  1. Build the images for TIBCO JasperReports® Server and Scalable Query Engine, see the [Docker TIBCO JasperReports® Server readme](../../Docker/jrs#readme) and [Docker Scalable Query Engine readme](../../Docker/scalableQueryEngine#readme). 
  2. Push the images to ECR, [see the docs](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html). 
  3. Add external repositories. 
    
    helm repo add haproxytech https://haproxytech.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    
  4. Run`helm dependencies update jrs/helm`.       
  5. Update the `jrs/helm/values.yaml` or use `--set <paramater_name>=<value>`. 
  6. Follow the [TIBCO JasperReports® Server installation procedure](#installing-tibco-jasperreports-server). 
  
  **Note:** Logging and monitoring are not required if EKS container insights are enabled. 


# Integrating the Scalable Query Engine and JasperReports Server

1. Enable the Scalable Query Engine to be installed by changing the `scalableQueryEngine.enabled = true` in values.yaml

   **Note:** By default Scalable Query Engine is disabled.
1. Update the `scalableQueryEngine.enabled=true` in [default_master.properties](../../Docker/jrs/resources/default-properties/default_master.properties) or use the js.config.properties as a customization .
1. Rebuild the JasperReports® Server Docker images   
1. Update the parameters if needed by changing `scalable-query-engine` section in values.yaml
1. Follow the [JasperReports Server installation procedure](#installing-jrs) to install the JasperReports Server, and the Scalable Query Engine will integrate automatically.   


# Use Case: Deploying TIBCO JasperReports® Server Using PostgreSQL Container in K8s Cluster
 
 
## Installation

1. Clone the jaspersoft-containers ``git clone git@github.com:tibco/jaspersoft-containers.git ``.
1. Run ``cd <CONTAINER_PATH>`` and download a commercial edition of TIBCO JasperReports® Server WAR File installer zip to your current directory.
1. Run ``cd jaspersoft-containers/Docker/jrs`` and update the `.env` if you need to change the version, chromium installation, etc.
1. Run ``cd scripts`` and then run ``./unpackWARInstaller.sh`` to unzip the installer file.
1. Update the dbHost in ``Docker/jrs/resources/default-properties/default_master.properties`` with the name ``repository-postgresql.<k8s-namespace>.svc.cluster.local`` to    create DB in K8s cluster.
1. Run ``cd ../``  and then run ``docker-compose build`` to build the images and if required, push it to the internal repository once the build is complete.
1. To tag and push images to the internal repository, [see this doc](https://docs.docker.com/engine/reference/commandline/push/#push-a-new-image-to-a-registry).
1. Run ``cd ../../K8s/jrs/helm`` and update the values.yaml for changing the image name, tag name, etc. (See the [Parameters](#parameters) section for more information)
1. To add the license file, run ``cd secrets/license`` and place the license in the folder. 
1. Run ``cd ../../``.
1. To add the keystore files, run ``cd secrets/keystore`` and place the keystore files in the folder and then run ``cd ../../``.
1. Run `` cd ../../ `` .
1. Add dependency chart repositories. 

       helm repo add bitnami https://charts.bitnami.com/bitnami
       helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
       helm repo add haproxytech https://haproxytech.github.io/helm-charts
       helm repo add elastic https://helm.elastic.co

1. Run ``helm dependencies update jrs/helm``. 

1. Install the PostgreSQL chart. 
   
   ``helm install repository bitnami/postgresql --set postgresqlPassword=postgres --namespace jrs --create-namespace``

   **Note:** Remove ``--create-namespace`` if ``jrs`` namespace already exists in the cluster.
  
   Check the pods status in the jrs namespace for PostgreSQL helm chart and make sure it is up and running.
   
1. After PostgreSQL is up and running, run ``helm install jrs jrs/helm --namespace jrs --wait --timeout 12m0s``.
  It will take few minutes to set up the DB and install the TIBCO JasperReports® Server webapp, JMS, and other addons like ingress controller, metrics, and logging.
 
1. Go to the http://HOSTNAME:Node-Port/jasperserver-pro or if Ingress is enabled, go to the http://EXTRENAL-IP/jasperserver-pro.

1. To access the metrics server using Grafana, use `` HOST_NAME:GRAFANA_NODEPORT `` command and enter the username/password as ``admin/prom-operator``.
  
    **Note:** If the password does not work, get the password using ``kubectl get secret --namespace jrs  jrs-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo``.

1. To access the kibana dashboard, use ``HOST_NAME:KIBANA_NODEPORT `` command.

1. If namespace or ports are changed, see the helm output for correct commands to access the application.
 
# Troubleshooting
- If repository setup fails due to password authentication, remove the PostgreSQL helm chart, and the persistent volume claim and then re-install the PostgreSQL chart by setting the password ``--set postgresqlPassword=postgres``
- If you encounter an issue with deployment due to keystore issues, check the [Keystore Generation](../../Docker/jrs#keystore-generation) steps to resolve this issue.
