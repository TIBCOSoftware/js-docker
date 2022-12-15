<details>
<summary>Table of Contents</summary>
<!-- TOC -->
  
- [Introduction](#introduction) 
  - [Prerequisites](#prerequisites)
  - [Parameters](#parameters)
  - [Adding Dependencies](#adding-dependencies)
- [Redis Configuration](#redis-configuration)
- [JNDI Configuration](#jndi-configuration)  
- [Installing Scalable Query Engine](#installing-scalable-query-engine)
- [Integrating Scalable Query Engine with TIBCO JasperReports&reg; Server](#integrating-scalable-query-engine-with-tibco-jasperreports-server)
  <!-- /TOC -->
  </details>


# Introduction
 These configuration files (Helm Charts) perform declarative configuration by using [Helm Package Manager](https://helm.sh/docs/) to deploy the
 TIBCO JasperReports&reg; Server Scalable Query Engine in Kubernetes cluster.

## Prerequisites

1. Docker-engine (19.x+) setup with Docker Compose V2 (3.9+)
1. K8s cluster with 1.19+
1. TIBCO JasperReports&reg; Server
1. Keystore   
1. Git
1. Helm 3.5   
1. Minimum knowledge of Docker and K8s

## Parameters

| Parameter| Description | Default Value |
|------------| -------------| ----------|
| replicaCount| Number of pods | 2 (It will not come into effect if autoscaling is enabled.)|
| jrsVersion| TIBCO JasperReports® Server release version  | 8.0.3|
| image.name| Name of the Scalable Query Engine image | null |
| image.tag | Name of the Scalable Query Engine image tag | JasperReports&reg; Server Release Version|
| image.pullPolicy | Docker image pull policy | IfNotPresent |
| image.PullSecrets | Name of the image pull secret | Pull secret should be created manually before using it in same namespace, [See Docs](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) |
| image.nameOverride | Override the default image name | "" |
| image.fullnameOverride | Override the complete image name | "" |
| foodmart.jdbcUrl | Foodmart db url  | repository-postgresql.{{.Release.Namespace }}.svc.cluster.local:5432/foodmart |
| foodmart.username | Foodmart db user name | postgres |
| foodmart.password |Password should be in base 64 encoded format and by default password is postgres.  |{} |
| sugarcrm.jdbcUrl | Sugarcrm db url | repository-postgresql.{{.Release.Namespace }}.svc.cluster.local:5432/sugarcrm |
| sugarcrm.username | Sugarcrm db username | postgres |
| sugarcrm.password | Password should be in base 64 encoded format and by default password is postgres.  | {} |
| audit.enabled | To enable the monitoring and auditing events in JasperReports&reg; Server | false |
| audit.jdbcUrl | Audit DB URL, by default, it uses the JasperReports&reg; Server DB url | repository-postgresql.{{.Release.Namespace }}.svc.cluster.local:5432/jasperserver |
| audit.userName | Audit DB user name | postgres |
| audit.password | Password should be in base 64 encoded format and by default, password is postgres. | {} |
| timeZone | Timezone to launch the pods |  UTC |
| appCredentialsSecretName| Secrets to store the datasource passwords | null |
| securityContext.capabilities.drop | Drops the Linux Host capabilities  | ALL |
| securityContext.runAsNonRoot | Runs the application as non-root user | true |
| securityContext.runAsUser | User id to run the application  | 11099 | 
| securityContext. allowPrivilegeEscalation | Allow Container host privileges  | false |
| Service.type | Scalable Query Engine service type | ClusterIP (for now, we kept as NodePort for internal testing)
| Service.port | Service port | 8080 |
| serviceAccount.enabled | Service account for Scalable Query Engine | true |
| serviceAccount.annotations | Annotations for service account | {} |
| serviceAccount.name | Service account name | query-engine |
| rbac.create | Creates role and role binding | true |
| rbac.name | Scalable Query Engine role and role binding name | query-engine-role |
| extraEnv.javaopts | Adds all JAVA_OPTS | -XX:+UseContainerSupport -XX:MinRAMPercentage=33.0 -XX:MaxRAMPercentage=80.0 -Xss2M -Djava.io.tmpdir=/tmp |
| extraEnv.normal | Adds all the normal key value pair variables  | null |
| extraEnv.secrets | Adds all the environment references from secrets or configmaps| null | 
| extraVolumeMounts | Adds extra volume mounts | null|
| extraVolumes | Adds extra volumes | null |
| healthcheck.enabled | Enables to check the Scalable Query Engine pod health status | true |
| healthcheck.livenessProbe.port | Scalable Query Engine container port | 8080 |
| healthcheck.livenessProbe.initialDelaySeconds | Initial delay seconds for application | 120 |
| healthcheck.livenessProbe.failureThreshold | Number of failure threshold count  | 24 |
| healthcheck.livenessProbe.periodSeconds | Period seconds | 10 |
| healthcheck.livenessProbe.timeoutSeconds | Timeout  | 4 |
| healthcheck.readinessProbe.port | Container port | 8080 |
| healthcheck.readinessProbe.initialDelaySeconds | Initial delay seconds for application  | 60 |
| healthcheck.readinessProbe.failureThreshold | Number of failure threshold count | 24 |
| healthcheck.readinessProbe.periodSeconds | Period seconds | 10 |
| healthcheck.readinessProbe.timeoutSeconds | Timeout | 4 |
| resources.enabled | Enables the minimum and maximum resources that can be used by Scalable Query Engine | true |
| resources.limits.cpu | Maximum CPU | "3" |
| resources.limits.memory | Maximum memory | 4Gi |
| resources.requests.cpu | Minimum CPU | "2" |
| resources.requests.memory | Minimum memory | 2Gi |
| ingress.enabled | Enables to work with multiple pods and stickyness | true |
| ingress.hosts.host | Adds the valid DNS hostname to access the Scalable Query Engine | null |
| ingress.hosts.paths.path | Application context path | /query-engine | 
| ingress.hosts.paths.pathType | Path type | Prefix |
| ingress.tls[0].secretName | Adds TLS secret name to allow secure traffic | null| 
| rediscluster.enabled | Enables the redis cluster  | true |
| rediscluster.externalRedisClusteraddress |  Adds external redis cluster address, if this is enabled, default redis cluster will skip | {} |
| rediscluster.externalRedisClusterpassword |  Adds external redis cluster password | {} |
| redis-cluster.nameOverride | Redis cluster name override  | query-engine-redis-cluster |
| redis-cluster.cluster.nodes | Number of nodes for redis cluster  | 6 |
| redis-cluster.persistence.size | PVC size for each redis node   | 8Gi |
| global.redis.password | Default redis password  | ZI85uBweKn |
| autoscaling.enabled | Enables the pod autoscaler for Scalable Query Engine. Note: Metrics server should be installed so that it will be available for the autoscaler to work.  | false|
| autoscaling.minReplicas | Minimum number of pods  | 2|
| autoscaling.maxReplicas | Maximum number of pods  | 10|
| autoscaling.targetCPUUtilizationPercentage| Minimum average CPU utliization to scale up the pods  | 50% |
| autoscaling.targetMemoryUtilizationPercentage | Minimum average memory utliization to scale up the pods  | {}|
| autoscaling.scaleDown.stabilizationWindowSeconds | Minimum time to scale down the pod   | 300|
| ingressclass | Ingress class used by ingress | intranet |
| kubernetes-ingress.controller.replicaCount | Ingress controller replica count  | 1 |
| kubernetes-ingress.controller.service.type | Service type for ingress controller | LoadBalancer |
| kubernetes-ingress.nameOverride | Ingress name | query-engine-ingress |
| kubernetes-ingress.controller.ingressClass | Ingress class name | intranet |
| kubernetes-ingress.controller.config.timeout-connect | Ingress imeout  | 30s |
| kubernetes-ingress.controller.config.timeout-check | Ingress timeout check | 60s |
| kubernetes-ingress.controller.config.timeout-client | Ingress client timeout | 240s |
| kubernetes-ingress.controller.config.timeout-server|  Ingress server timeout| 240s |
| kubernetes-ingress.defaultBackend.replicaCount | Ingress controller replica count  | 1 |
| kubernetes-ingress.controller.config.timeout-check | Ingress controller timeout | 60s |
| kubernetes-ingress.controller.config.timeout-server | Ingress controller backend timeout | 240s |
| kubernetes-ingress.controller.config.timeout-client | Ingress controller frontend timeout | 240s |
| kubernetes-ingress.controller.config.maxconn | Max connections ingress can accept | 1000 |
| server.tomcat.connectionTimeout | Tomcat connection timeout for request  | 300000 |
| jrs.server.scheme | JasperReports&reg; Server schema | http |
| jrs.server.host |  JasperReports&reg; Server hostname| "{{ .Release.Name }}-jasperserver-ingress.{{ .Release.Namespace }}.svc.cluster.local" |
| jrs.server.port | JasperReports&reg; Server port | 80 |
| jrs.server.path | JasperReports&reg; Server path | jasperserver-pro/rest_v2 |
| jrs.server.username | JasperReports&reg; Server username | jasperadmin |
| jrs.proxy.enabled | Enables the proxy for scalable Query Engine   | true |
| jrs.proxy.scheme | Scalable Query Engine scheme  | http |
| jrs.proxy.host | Scalable Query engine host  | "{{ .Release.Name }}-query-engine-ingress.{{ .Release.Namespace }}.svc.cluster.local" |
| jrs.proxy.port | Scalable Query engine port | 80 |
| jrs.proxy.path | Scalable Query engine path | rest_v2 |
| jrs.proxy.username | Scalable Query Engine user name | jasperadmin |
| jrs.proxy.timedOut | timeout | 30000 |
| drivers.image.enabled | Enables the drivers  | true |
| drivers.image.name | Image name for Scalable Query Engine Driver image | null |
| drivers.image.tag | Scalable Query Engine Driver image tag | 8.0.3 |
| drivers.image.pullPolicy | Image pull policy | IfNotPresent |
| drivers.storageClassName | Driver image storage class name | hostPath |
| drivers.image.jdbcDriversPath | JDBC drivers path  | /usr/lib/drivers |
| metrics.enabled | Enables the Prometheus metrics | false |
| kube-prometheus-stack.prometheus-node-exporter.hostRootFsMount | Mount the prometheus in host system  | false |
| kube-prometheus-stack.grafana.service.type | Grafana Service Type | NodePort|
| logging.enabled | Enables the Elasticsearch, Fluentd and Kibana(EFK) logging | false|
| logging.level | Scalable Query Engine logging level | INFO |
| logging.pretty | Scalable Query Engine logging format | false |
| fluentd.imageName | Fluentd image name | fluent/fluentd-kubernetes-daemonset |
| fluentd.imageTag |Fluentd image tag  | v1.12.3-debian-elasticsearch7-1.0 |
| fluentd.esClusterName  | Fluentd elasticsearch cluter name | elasticsearch |
| fluentd.esPort | elasticsearch port | 9200 |
| elasticsearch.replicas | Number of pods for elasticsearch  |  1 |
| elasticsearch.volumeClaimTemplate.resources.requests.storage | | 10Gi |
| kibana.service.type | Kibana service type | NodePort |


## Adding Dependencies 

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add haproxytech https://haproxytech.github.io/helm-charts
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo add elastic https://helm.elastic.co

To update the dependencies, run `cd <CONAINER_PATH>/K8s` and then run `helm dependencies update scalableQueryEngine/helm`.

# Redis Configuration
  By default, Scalable Query Engine comes with the redis cluster by using [bitnami/redis-cluster](https://artifacthub.io/packages/helm/bitnami/redis-cluster) helm chart.
External redis configuration can also be used by adding the redis url for `rediscluster.externalRedisClusteraddress` and `rediscluster.externalRedisClusterpassword` parameters.
**Note:** If the values of these parameters are provided, then the default redis-cluster Helm chart installation will be skipped.

# JNDI Configuration

  You can add any new JNDI in `config/jndi.properties` in the below formats.


    jndi.dataSources[3].name=jdbc/<jdbc-name>
    jndi.dataSources[3].auth=Container
    jndi.dataSources[3].factory=com.jaspersoft.jasperserver.tomcat.jndi.JSCommonsBasicDataSourceFactory
    jndi.dataSources[3].driverClassName=<JDBC-Driver-class-Name>
    jndi.dataSources[3].url=jdbc:postgresql://<Databse-Host-name:<Port>/<DB_NAME> >
    jndi.dataSources[3].username=<DB USer Name>
    jndi.dataSources[3].password=<PASSWORD> or configure the password in templates/app-config.yml and provide the variable name here
    jndi.dataSources[3].accessToUnderlyingConnectionAllowed=true
    jndi.dataSources[3].validationQuery=SELECT 1
    jndi.dataSources[3].testOnBorrow=true
    jndi.dataSources[3].maxActive=100
    jndi.dataSources[3].maxIdle=30
    jndi.dataSources[3].maxWait=10000

# Installing Scalable Query Engine
1. Build the Scalable Query Engine images, see the instructions at [Docker scalableQueryEngine Readme](../../Docker/scalableQueryEngine).
1. Go to `cd <CONTAINER_PATH>/K8s`.
1. Copy the JasperReports&reg; Server keystore to `./scalableQueryEngine/helm/secrets/keystore`, if keystore does not exist, generate the keystore (see here for [Keystore Generation](../../Docker/jrs/#keystore-generation)).   
1. Update the values.yaml if needed or set the values to the chart dynamically through passing `--set <parameter_name>=<paramter_value>`.
1. Run `helm install engine scalableQueryEngine/helm`.
1. Get the ingress external IP or nodeport and check the engine status at `<EXTERNAL_IP>/query-engine/actuator/health`.

# Integrating Scalable Query Engine with TIBCO JasperReports&reg; Server

1. Get the ingress external IP of Scalable Query Engine.
1. Set the `SCALABLE_QUERY_ENGINE_URL` as an environment variable in JasperReports&reg; Server.
1. Enable the scalableQueryEngine.enabled to true in js.config.properties
1. Update  the `jrs.server` section in values.yaml with JasperReports&reg; Server configuration details 
1. Restart the JasperReports&reg; Server application to reflect the changes.
1. Install the Scalable Query Engine Helm chart.
