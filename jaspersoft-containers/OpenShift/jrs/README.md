


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
This helm chart is used to install JasperReports® Server in OpenShift and integrate it with the JasperReports® Server Scalable Query Engine.

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

| Parameter| Description | default Value |
|------------| -------------| ----------|
| replicaCount| Number of pods | 1 (It will not come into effect if autoscaling is enabled.)| 
| jrsVersion| JasperReports® Server release version | 8.2.0 | 
| image.tag | Name of the JasperReports® Server webapp image tag | JasperReports® Server Release Version|
| image.name| Name of the JasperReports® Server webapp image | jrscontainerregistry.azurecr.io/jrs/webapp|
| image.pullPolicy| Docker image pull policy  | IfNotPresent|
| image.PullSecrets | Name of the image pull secret | Pull secret should be created manually before using it in same namespace, [See Docs](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) |
| nameOverride| Override the default helm chart name  | "" |
| fullnameOverride| Override the default full chart name | "" |
| secretKeyStoreName| Name of the keystore secret | jasperserver-keystore|
| secretLicenseName | Name of the license secret | jasperserver-license|
| serviceAccount.enabled | Service account for JasperReports® Server webapp | true |
| serviceAccount.annotations | Adds new annotations | null |
| serviceAccount.name | Name of the service account | jasperserver-pro |
| rbac.create | Creates role and role binding | true |
| rbac.name | Name of the JasperReports® Server role and role binding | jasperserver-role |
| podAnnotations | Adds pod annotations | null |
| securityContext.capabilities.drop | Drops Linux capabilites for the JasperReports® Server webapp  | All |
| securityContext.runAsNonRoot | Runs the JasperReports® Server webapp as non root user | true |
| securityContext.runAsUser | User id to run the JasperReports® Server webapp | 10099 |
| buildomatic.enabled | Installs or skips the JasperReports® Server repository DB | true|
| buildomatic.name | Name of the JasperReports® Server command line tool | jasperserver-buildomatic|
| buildomatic.imageTag| Buildomatic image tag | Same as JasperReports® Server release version|
| buildomatic.imageName | Name of the buildomatic image | jrscontainerregistry.azurecr.io/jrs/buildomatic|
| buildomatic.pullPolicy | Image pull policy| IfNotPresent|
| buildomatic.PullSecrets | Image pull secrets | acr-secret|
| buildomatic.includeSamples| Installs JasperReports® Server samples in JasperReports Server DB | true|
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
| Service.type | JasperReports® Server service type | ClusterIP (for now, we kept as NodePort for internal testing)
| Service.port | Service port | 80 |
| healthcheck.enabled | Checks JasperReports® Server pod health status | true |
| healthcheck.livenessProbe.port | JasperReports® Server container port  | 8080 |
| healthcheck.livenessProbe.initialDelaySeconds | Initial waiting time to check the health and restarts the JasperReports® Server Webapp pod | 350 |
| healthcheck.livenessProbe.failureThreshold | Threshold for health checks | 10 |
| healthcheck.livenessProbe.periodSeconds |Time period to check the health | 10 |
| healthcheck.livenessProbe.timeoutSeconds | Timeout | 4 |
| healthcheck.readinessProbe.port | JasperReports® Server container port | 8080 |
| healthcheck.readinessProbe.initialDelaySeconds | Initial delay before checking the health checks | 90 |
| healthcheck.readinessProbe.failureThreshold | Threshold for health checks | 15 |
| healthcheck.readinessProbe.periodSeconds | Time period to check the health checks | 10 |
| healthcheck.readinessProbe.timeoutSeconds | Timeout | 4 |
| resources.enabled | Enables the minimum and maximum resources used by JasperReports® Server | true |
| resources.limits.cpu | Maximum CPU  | "3" |
| resources.limits.memory | Maximum memory | 7.5Gi |
| resources.requests.cpu | Minimum CPU | "2" |
| resources.requests.memory | Minimum memory | 3.5Gi |
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
| ingress.hosts.host | Adds valid DNS hostname to access the JasperReports® Server | null|
| ingress.tls | Adds TLS secret name to allow secure traffic | null| 
| scalableQueryEngine.enabled | Communicates with Scalable Query Engine | false|
| scalable-query-engine.replicaCount | Number of pods for Scalable Query Engine | 1|
| scalable-query-engine.image.tag | Scalable Query Engine image tag | 8.2.0|
| scalable-query-engine.image.name | Name of the Scalable Query Engine image | null |
| scalable-query-engine.image.pullPolicy| Scalable Query Engine image pull policy | ifNotPresent |
| scalable-query-engine.autoscaling.enabled | Enables the HPA for Scalable Query Engine | true |
| scalable-query-engine.drivers.image.tag | Scalable Query Engine image tag | 8.2.0 |
| scalable-query-engine.drivers.image.name |  | null |
| scalable-query-engine.drivers.storageClassName |   | hostpath |
| scalable-query-engine.kubernetes-ingress.controller.service.type |  | ClusterIP |
| autoscaling.enabled | Scales the JasperReports Server application,  **Note:** Make sure metric server is installed or metrics are enabled | true |
| autoscaling.minReplicas | Minimum number of pods maintained by autoscaler | 1 |
| autoscaling.maxReplicas | Maximum number of pods maintained by autoscaler | 4 |
| autoscaling.targetCPUUtilizationPercentage | Minimum CPU utilization to scale up the application | 50% |
| autoscaling.targetMemoryUtilizationPercentage | Minimum memory utilization to scale up the JasperReports® Server applications | {} |
| tolerations | Adds the tolerations as per K8s standard if needed | null |
| affinity | Adds the affinity as per K8s standards if needed | null |

# Adding External Helm Repositories

    helm repo add haproxytech https://haproxytech.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami

# Setting Java options
During the deployment of JasperReports® Server with helm, JAVA_OPTS can be specified within the `OpenShift/jrs/helm/values.yaml` file.
This configuration option enables customization of the Java Virtual Machine settings, which can optimize the performance of the JasperReports® Server application.

If deploying JasperReports® Server with docker images based on JDK17, an additional JAVA_OPTS options need to be added in the in `OpenShift/jrs/helm/values.yaml` file:

```yaml
extraEnv:
 javaOpts: "-XX:+UseContainerSupport -XX:MinRAMPercentage=33.0 -XX:MaxRAMPercentage=75.0 --add-opens java.base/java.io=ALL-UNNAMED --add-opens java.base/java.lang.ref=ALL-UNNAMED --add-opens java.base/java.lang=ALL-UNNAMED --add-opens java.base/java.nio.channels.spi=ALL-UNNAMED --add-opens java.base/java.nio.channels=ALL-UNNAMED --add-opens java.base/java.nio=ALL-UNNAMED --add-opens java.base/java.security=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens java.base/java.util.concurrent.locks=ALL-UNNAMED --add-opens java.base/java.util.concurrent=ALL-UNNAMED --add-opens java.base/java.util.regex=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/javax.security.auth.login=ALL-UNNAMED --add-opens java.base/javax.security.auth=ALL-UNNAMED --add-opens java.base/jdk.internal.access.foreign=ALL-UNNAMED --add-opens java.base/sun.net.util=ALL-UNNAMED --add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.rmi/sun.rmi.transport=ALL-UNNAMED --add-opens java.base/sun.util.calendar=ALL-UNNAMED"
```

# Installing JasperReports® Server

1. Go to `jaspersersoft-containers/OpenShift` and to update the dependency charts, run `helm dependencies update jrs/helm`.
2. **Optional Step**: is required only if you plan to use environment variables from **Kubernetes Secrets** to pass `jasperserver` database details.
This option can be useful when the JasperReports® Server application needs to connect to its repository database, which is deployed externally and already loaded. 
Repository details will be stored in Kubernetes secrets and will be used as environment variables during application startup.

There are two ways to manage the Kubernetes Secret for passing `jasperserver` database details:

- The Secret can be automatically generated from the values provided in `OpenShift/jrs/helm/values.yaml`. This approach simplifies the Secret management process by automatically populating it with the required details and deploying it.
- Alternatively, you can create a **Custom Kubernetes Secret** and deploy it into the cluster. This option provides greater control over the Secret contents and can be useful when specific Secrets management requirements need to be met.  

Note that both options can only be used when the `jasperserver` repository database is already created and loaded.

The first step in either case is to set `buildomatic.enabled` to **false** in `OpenShift/jrs/helm/values.yaml`.
This setting instructs the Helm chart to skip the `jasperserver-buildomatic` job that creates and loads the repository database. 

 
**Option 1: Automatically generated Kubernetes Secret**
   
Update the `db` section in `OpenShift/jrs/helm/values.yaml`, set `db.env` to **true**. Then, configure the `jrs` sub-section with the necessary database details. Note that you should not pass a `secretName` in this case.
Here is configuration example:
```yaml
db:
  env: true
  secretName:
  jrs:
    dbHost: repository-postgresql.default.svc.cluster.local
    dbPort: 5432
    dbName: jasperserver
    dbUserName: postgres
    dbPassword: postgres
```

**Note** that in this example, the `jasperserver` database was pre-created using the PostgreSQL Helm chart from this guide, and it is part of the same Kubernetes cluster in the default namespace.
If JasperReports® Server is deployed in a different namespace or cluster, update the `dbHost` parameter in the following format: `<helm-name>-postgresql.<namespace>.svc.cluster.<cluster-name>`.
If the JasperReports® Server repository database is deployed remotely, such as in AWS RDS, then set the `dbHost` to a value that is accessible from the Kubernetes cluster.  

With this step completed, you can move on to the next installation instructions.


**Option 2: Custom Kubernetes Secret**
   
First create a separate secret in `OpenShift/jrs/helm/templates` folder, for example:
  
**Filename**: `OpenShift/jrs/helm/templates/envsecret.yaml`
   
```yaml
  apiVersion: v1
  kind: Secret
  type: Opaque
  metadata:
    name: custom-db-secret
    labels:
  data:
    DB_HOST: host-name
    DB_PORT: port-name
    DB_NAME: db-name
    DB_USER_NAME: db-user-name
    DB_PASSWORD:  db-password
```

**Note**: Every variable value under `data` section should be encoded in base64 format. You can use the following command to encode a string in base64 on Linux: 
```commandline
echo -n "my-password" | base64
```
On Windows use powershell command that can encode text in file:
```
certutil -f -encode raw.txt encoded.txt
```

After the secret file is created and the values are encoded in base64, it has to be deployed into the Kubernetes cluster using the following command:
```commandline
oc apply -f OpenShift/jrs/helm/templates/envsecret.yaml
```

Then edit `OpenShift/jrs/helm/values.yaml` and go to the `db` section. Set `env` to **true** and pass the secret name that you created. For example: 
  
```yaml
db:
  env: true
  secretName: custom-db-secret
  jrs:
    dbHost: repository-postgresql.default.svc.cluster.local
    dbPort: 5432
    dbName: jasperserver
    dbUserName: postgres
    dbPassword: postgres
```  
**Note**: when `secretName` is set, then all properties under `jrs` sub-section will be ignored.
     
You may now proceed to the next steps of the installation.


**JasperReports® Server Compact and Split installation**
- In Compact installation mode (default), all audit events will be stored in the same repository database.
- In Split installation mode (selected in default_master.properties), audit events will be stored in a separate database.

To use the secrets for Compact installation, no additional configuration is required.

To use the secrets for Split installation, first ensure that the audit database has already been created, loaded, and is accessible.

Then, set `db.audit.enable=true` in `OpenShift/jrs/helm/values.yaml` to get automatically generated secret:

```yaml
db:
  env: false
  secretName:
  jrs:
    dbHost: repository-postgresql.default.svc.cluster.local
    dbPort: 5432
    dbName: jasperserver
    dbUserName: postgres
    dbPassword: postgres
  audit:
    enabled: true
    dbHost: repository-postgresql.default.svc.cluster.local
    dbPort: 5432
    dbName: jrsaudit
    dbUserName: postgres
    dbPassword: postgres
```

or update your custom secret file `OpenShift/jrs/helm/templates/envsecret.yaml` with additional properties for Audit DB:

```yaml
  apiVersion: v1
  kind: Secret
  type: Opaque
  metadata:
    name: custom-db-secret
    labels:
  data:
    DB_HOST: host-name
    DB_PORT: port-name
    DB_NAME: db-name
    DB_USER_NAME: db-user-name
    DB_PASSWORD: db-password
    AUDIT_DB_HOST: audit-db-host
    AUDIT_DB_PORT: audit-db-port
    AUDIT_DB_NAME: audit-db-name
    AUDIT_DB_USER_NAME: audit-db-user-name
    AUDIT_DB_PASSWORD: audit-password
```
3. Build the docker images for JasperReports® Server, and Scalable Query Engine (see the [Docker JasperReports Server readme](../../Docker/jrs#readme) and [Docker Scalable Query Engine readme](../../Docker/scalableAdhocWorker#readme) ).
4. Generate the keystore and copy it to the `OpenShift/jrs/helm/secrets/keystore` folder, see here for [Keystore Generation ](../../Docker/jrs#keystore-generation).
5. Copy the JasperReports® Server license to the `OpenShift/jrs/helm/secrets/license` folder.

## JMS Configuration
By default, JasperReports® Server will install using activemq docker image. You can disable it by changing the parameter `jms.enabled=false`.

External JMS instance can also be used instead of in-build JMS setup by adding the external jms url `jms.jmsBrokerUrl`. You can access it by using tcp port, for instance `tcp://<JMS-URL>:61616`.

## Repository DB Does Not Exist

-  To set up the Repository DB in the OpenShift cluster, run the below command. For this, we are using bitnami/postgresql Helm chart. See the [Official Docs](https://artifacthub.io/packages/helm/bitnami/postgresql) to configure the DB in cluster mode.

`helm install repository bitnami/postgresql --set auth.postgresPassword=postgres  --version 11.9.13 `


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

