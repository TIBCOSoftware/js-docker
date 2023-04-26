


<details>
<summary>Table of Contents</summary>
<!-- TOC -->

- [Introduction](#introduction)
    - [Prerequisites](#prerequisites)
    - [Parameters](#parameters)
    - [Adding External Helm Repositories](#adding-external-helm-repositories)
- [Installing JasperReports® Server](#installing-jasperreports-server)
    - [JMS Configuration](#jms-configuration)
    - [Repository DB Does Not Exist](#repository-db-does-not-exist)
    - [Repository DB Already Exists](#repository-db-already-exists)
    - [Route Configuration](#route-configuration)
- [Integrating the Scalable Query Engine and JasperReports Server](#integrating-the-scalable-query-engine-and-jasperreports-server)
- [Troubleshooting](#troubleshooting)
  <!-- /TOC -->
  </details>


# Introduction
This helm chart is used to install  JasperReports® Server in OpenShift and integrate it with the JasperReports® Server Scalable Query Engine.

# Prerequisites
1. Docker-engine (19.x+) setup with Docker Compose  (3.9+)
1. OpenShift cluster with 4.6+
1. JasperReports® Server
1. Keystore
1. Git
1. [Helm 3.5](https://helm.sh/docs/intro/)
1. [OpenShift command-line interface (CLI)](https://docs.openshift.com/container-platform/4.8/cli_reference/openshift_cli/getting-started-cli.html)   
1. Minimum knowledge of Docker and OpenShift

# Parameters

These parameters and values are the same as parameters in values.yaml.

| Parameter| Description | default Value                                                                                                                                                               |
|------------| -------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| replicaCount| Number of pods | 1 (It will not come into effect if autoscaling is enabled.)                                                                                                                 | 
| jrsVersion| JasperReports® Server release version | 8.0.4                                                                                                                                                                       | 
| image.tag | Name of the JasperReports® Server webapp image tag | JasperReports® Server Release Version                                                                                                                                       |
| image.name| Name of the JasperReports® Server webapp image | jrscontainerregistry.azurecr.io/jrs/webapp                                                                                                                                  |
| image.pullPolicy| Docker image pull policy  | IfNotPresent                                                                                                                                                                |
| image.PullSecrets | Name of the image pull secret | Pull secret should be created manually before using it in same namespace, [See Docs](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) |
| nameOverride| Override the default helm chart name | ""                                                                                                                                                                          |
| fullnameOverride| Override the default full chart name | ""                                                                                                                                                                          |
| secretKeyStoreName| Name of the keystore secret | jasperserver-keystore                                                                                                                                                       |
| secretLicenseName | Name of the license secret | jasperserver-license                                                                                                                                                        |
| serviceAccount.enabled | Service account for JasperReports® Server webapp | true                                                                                                                                                                        |
| serviceAccount.annotations | Adds new annotations | null                                                                                                                                                                        |
| serviceAccount.name | Name of the service account | jasperserver-pro                                                                                                                                                            |
| rbac.create | Creates role and role binding | true                                                                                                                                                                        |
| rbac.name | Name of the JasperReports® Server role and role binding | jasperserver-role                                                                                                                                                           |
| podAnnotations | Adds pod annotations | null                                                                                                                                                                        |
| securityContext.capabilities.drop | Drops Linux capabilites for the JasperReports® Server webapp | All                                                                                                                                                                         |
| securityContext.runAsNonRoot | Runs the JasperReports® Server webapp as non root user | true                                                                                                                                                                        |
| securityContext.runAsUser | User id to run the JasperReports® Server webapp | 10099                                                                                                                                                                       |
| buildomatic.enabled | Installs or skips the JasperReports® Server repository DB | true                                                                                                                                                                        |
| buildomatic.name | Name of the JasperReports® Server command line tool | jasperserver-buildomatic                                                                                                                                                    |
| buildomatic.imageTag| Buildomatic image tag | Same as JasperReports® Server release version                                                                                                                               |
| buildomatic.imageName | Name of the buildomatic image | jrscontainerregistry.azurecr.io/jrs/buildomatic                                                                                                                             |
| buildomatic.pullPolicy | Image pull policy| IfNotPresent                                                                                                                                                                |
| buildomatic.PullSecrets | Image pull secrets | acr-secret                                                                                                                                                                  |
| buildomatic.includeSamples| Installs JasperReports® Server samples in JasperReports Server DB | true                                                                                                                                                                        |
| db.env | Enables the DB configuration using environment variables | true                                                                                                                                                                        |
| db.jrs.dbHost | JasperReports Server repository DB host | repository-postgresql.default.svc.cluster.local                                                                                                                             |
| db.jrs.dbPort | JasperReports Server repository DB port | 5432                                                                                                                                                                        |
| db.jrs.dbName | JasperReports Server repository DB name | jasperserver                                                                                                                                                                |
| db.jrs.dbUserName | JasperReports Server repository DB user name | postgres                                                                                                                                                                    |
| db.jrs.dbPassword | JasperReports Server repository DB password | postgres                                                                                                                                                                    |
| db.audit.dbHost | JasperReports Server audit DB host | repository-postgresql.default.svc.cluster.local                                                                                                                             |
| db.audit.dbPort | JasperReports Server audit DB port | 5432                                                                                                                                                                        |
| db.audit.dbName | JasperReports Server audit DB name | jasperserver                                                                                                                                                                |
| db.audit.dbUserName | JasperReports Server audit DB user name | postgres                                                                                                                                                                    |
| db.audit.dbPassword | JasperReports Server audit DB password | postgres                                                                                                                                                                    |
| extraEnv.javaopts | Adds all JAVA_OPTS  | -XX:+UseContainerSupport -XX:MinRAMPercentage=33.0 -XX:MaxRAMPercentage=75.0                                                                                                |
| extraEnv.normal | Adds all the normal key value pair variables | null                                                                                                                                                                        |
| extraEnv.secrets | Adds all the environment references from secrets or configmaps| null                                                                                                                                                                        | 
| extraVolumeMounts | Adds extra volume mounts | null                                                                                                                                                                        |
| extraVolumes | Adds extra volumes | null                                                                                                                                                                        |
| Service.type | JasperReports® Server service type | ClusterIP (for now, we kept as NodePort for internal testing)                                                                                                               
| Service.port | Service port | 80                                                                                                                                                                          |
| healthcheck.enabled | Checks JasperReports® Server pod health status | true                                                                                                                                                                        |
| healthcheck.livenessProbe.port | JasperReports® Server container port | 8080                                                                                                                                                                        |
| healthcheck.livenessProbe.initialDelaySeconds | Initial waiting time to check the health and restarts the JasperReports® Server Webapp pod | 350                                                                                                                                                                         |
| healthcheck.livenessProbe.failureThreshold | Threshold for health checks | 10                                                                                                                                                                          |
| healthcheck.livenessProbe.periodSeconds |Time period to check the health | 10                                                                                                                                                                          |
| healthcheck.livenessProbe.timeoutSeconds | Timeout | 4                                                                                                                                                                           |
| healthcheck.readinessProbe.port | JasperReports® Server container port | 8080                                                                                                                                                                        |
| healthcheck.readinessProbe.initialDelaySeconds | Initial delay before checking the health checks | 90                                                                                                                                                                          |
| healthcheck.readinessProbe.failureThreshold | Threshold for health checks | 15                                                                                                                                                                          |
| healthcheck.readinessProbe.periodSeconds | Time period to check the health checks | 10                                                                                                                                                                          |
| healthcheck.readinessProbe.timeoutSeconds | Timeout | 4                                                                                                                                                                           |
| resources.enabled | Enables the minimum and maximum resources used by JasperReports® Server | true                                                                                                                                                                        |
| resources.limits.cpu | Maximum CPU  | "3"                                                                                                                                                                         |
| resources.limits.memory | Maximum memory | 7.5Gi                                                                                                                                                                       |
| resources.requests.cpu | Minimum CPU | "2"                                                                                                                                                                         |
| resources.requests.memory | Minimum memory | 3.5Gi                                                                                                                                                                       |
| jms.enabled | Enables the ActiveMQ cache service | true                                                                                                                                                                        |
| jms.jmsBrokerUrl |  | null                                                                                                                                                                        |
| jms.name | Name of the JMS | jasperserver-cache                                                                                                                                                          |
| jms.serviceName | Name of the JMS Service | jasperserver-cache-service                                                                                                                                                  |
| jms.imageName | Name of the Activemq image | bansamadev/activemq                                                                                                                                                         |
| jms.imageTag | Activemq image tag | 5.17.2                                                                                                                                                                      |
| jms.healthcheck.enabled |  | true                                                                                                                                                                        |
| jms.healthcheck.livenessProbe.port | Container port | 61616                                                                                                                                                                       |
| jms.healthcheck.livenessProbe.initialDelaySeconds | Initial delay  | 100                                                                                                                                                                         |
| jms.healthcheck.livenessProbe.failureThreshold | Threshold for health check | 10                                                                                                                                                                          |
| jms.healthcheck.livenessProbe.periodSeconds | Time period for health check | 10                                                                                                                                                                          |
| jms.healthcheck.readinessProbe.port | Container port | 61616                                                                                                                                                                       |
| jms.healthcheck.readinessProbe.initialDelaySeconds | Initial delay  | 10                                                                                                                                                                          |
| jms.healthcheck.readinessProbe.failureThreshold | Threshold for health check | 15                                                                                                                                                                          |
| jms.healthcheck.readinessProbe.periodSeconds | Time period for health check | 10                                                                                                                                                                          |
| jms.securityContext.capabilities.drop | Linux capabilities to drop for the pod | All                                                                                                                                                                         |
| ingress.enabled | Work with multiple pods and stickyness | false                                                                                                                                                                       |
| ingress.annotations.ingress.kubernetes.io\/cookie-persistence|  | "JRS_COOKIE"                                                                                                                                                                |
| ingress.hosts.host | Adds valid DNS hostname to access the JasperReports® Server | null                                                                                                                                                                        |
| ingress.tls | Adds TLS secret name to allow secure traffic | null                                                                                                                                                                        | 
| scalableQueryEngine.enabled | Communicates with Scalable Query Engine | false                                                                                                                                                                       |
| scalable-query-engine.replicaCount | Number of pods for Scalable Query Engine | 1                                                                                                                                                                           |
| scalable-query-engine.image.tag | Scalable Query Engine image tag | 8.0.4                                                                                                                                                                       |
| scalable-query-engine.image.name | Name of the Scalable Query Engine image | null                                                                                                                                                                        |
| scalable-query-engine.image.pullPolicy| Scalable Query Engine image pull policy | ifNotPresent                                                                                                                                                                |
| scalable-query-engine.autoscaling.enabled | Enables the HPA for Scalable Query Engine | true                                                                                                                                                                        |
| scalable-query-engine.drivers.image.tag | Scalable Query Engine image tag | 8.0.4                                                                                                                                                                       |
| scalable-query-engine.drivers.image.name |  | null                                                                                                                                                                        |
| scalable-query-engine.drivers.storageClassName |   | hostpath                                                                                                                                                                    |
| scalable-query-engine.kubernetes-ingress.controller.service.type |  | ClusterIP                                                                                                                                                                   |
| autoscaling.enabled | Scales the JasperReports Server application,  **Note:** Make sure metric server is installed or metrics are enabled | true                                                                                                                                                                        |
| autoscaling.minReplicas | Minimum number of pods maintained by autoscaler | 1                                                                                                                                                                           |
| autoscaling.maxReplicas | Maximum number of pods maintained by autoscaler | 4                                                                                                                                                                           |
| autoscaling.targetCPUUtilizationPercentage | Minimum CPU utilization to scale up the application | 50%                                                                                                                                                                         |
| autoscaling.targetMemoryUtilizationPercentage | Minimum memory utilization to scale up the JasperReports® Server applications | {}                                                                                                                                                                          |
| tolerations | Adds the tolerations as per K8s standard if needed | null                                                                                                                                                                        |
| affinity | Adds the affinity as per K8s standards if needed | null                                                                                                                                                                        |

# Adding External Helm Repositories

    helm repo add haproxytech https://haproxytech.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami


# Installing JasperReports® Server

1. Go to `jaspersersoft-containers/OpenShift` and to update the dependency charts, run `helm dependencies update jrs/helm`.
2. (Optional , in case DB has to be configure using env variables)Update the `db` section in `values.yaml` with the actual JasperReports Server DB details or create a separate secret like below.
   

      
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
 If JasperReports Server is deployed in a different project, then change the dbHost in the following format: `respository-postgresql.<OpenShift-project>.svc.cluster.local`.
   

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

3. Build the docker images for JasperReports® Server, and Scalable Query Engine (see the [Docker JasperReports Server readme](../../Docker/jrs#readme) and [Docker Scalable Query Engine readme](../../Docker/scalableAdhocWorker#readme) ).
4. Generate the keystore and copy it to the `OpenShift/jrs/helm/secrets/keystore` folder, see here for [Keystore Generation ](../../Docker/jrs#keystore-generation).
5. Copy the JasperReports® Server license to the `OpenShift/jrs/helm/secrets/license` folder.

## JMS Configuration
By default, JasperReports® Server will install using activemq docker image. You can disable it by changing the parameter `jms.enabled=false`.

External JMS instance can also be used instead of in-build JMS setup by adding the external jms url `jms.jmsBrokerUrl`. You can access it by using tcp port, for instance `tcp://<JMS-URL>:61616`.

## Repository DB Does Not Exist

-  To set up the Repository DB in the OpenShift cluster, run the below command. For this, we are using bitnami/postgresql Helm chart. See the [Official Docs](https://artifacthub.io/packages/helm/bitnami/postgresql) to configure the DB in cluster mode.

`helm install repository bitnami/postgresql --set auth.postgresPassword=postgres  --version 11.9.13`


- Check the pods status and make sure pods are in a running state.

- Go to `jaspersoft-containers/OpenShift` and update the jrs/helm/values.yaml, see the [Parameter](#parameters) section for more information.

- Set **buildomatic.enabled=true** for repository setup. By default, samples are included, if it is not required, set **buildomatic.includeSamples=false**.

- Run the below command to install JasperReports® Server and repository setup.

`helm install jrs jrs/helm --wait --timeout 17m0s`

**Note:** If repository setup fails in the middle then increase the timeout.

## Repository DB Already Exists

``helm install jrs jrs/helm ``

List all the resources.

`` oc get all ``

## Route Configuration

OpenShift [Route](https://docs.openshift.com/container-platform/4.8/networking/routes/route-configuration.html) is used to manage the traffic across the JasperReports® Server pods and session replication. By default, it is enabled and created in the OpenShift cluster.

To get the host name, run the below command:

        oc get route jrs-jasperserver-pro  -o jsonpath='{.status.ingress[0].host}'

See the [ Official Docs](https://docs.openshift.com/container-platform/4.8/networking/routes/secured-routes.html) for TLS configuration. You can do it from the OpenShift webconsole or update the `route.tls` section in values.yaml.

# Integrating the Scalable Query Engine and JasperReports® Server

1. Enable the Scalable Query Engine to be installed by changing the `scalableQueryEngine.enabled = true`.

   **Note:** By default, Scalable Query Engine is disabled.

2. Update the parameters if needed by changing the `scalable-query-engine` section in values.yaml.
3. Follow the [JasperReports Server installation procedure](#installing-jasperreports-server) to install the JasperReports Server, and the Scalable Query Engine will integrate automatically.


# Troubleshooting
- If repository setup fails due to password authentication, remove the PostgreSQL helm chart, and the persistent volume claim and then re-install the PostgreSQL chart by setting the password ``--set postgresqlPassword=postgres``.
- If you encounter an issue with deployment due to keystore issues, check the [Keystore Generation](../../Docker/jrs#keystore-generation) steps to resolve this issue.

