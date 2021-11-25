
{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "queryEngine.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Expand the name of the chart.
*/}}
{{- define "queryEngine.name" -}}
{{- default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "queryEngine.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "queryEngine.labels" -}}
helm.sh/chart: {{ include "queryEngine.chart" . }}
{{ include "queryEngine.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}



{{- define "queryBatch.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-%s" .Release.Name .Chart.Name "batch" | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "queryEngine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "queryEngine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/*
Queue selector
*/}}
{{- define "queryBatch.selectorLabels" -}}
app.kubernetes.io/name: {{ printf "%s-%s" "queryEngine.name" ""}}
{{- end }}

{{/*
Define env varibales here
*/}}

{{- define "workerEnv" -}}
env:
 - name: SPRING_APPLICATION_NAME
   value: {{ include "queryEngine.fullname" . }}
 - name: WORKER_ID
   valueFrom:
     fieldRef:
       fieldPath: metadata.name
 - name: JAVA_TOOL_OPTIONS
   value: " {{ .Values.extraEnv.javaOpts }} "
 - name: LOADER_PATH
   value: /etc/config,BOOT-INF/classes,BOOT-INF/lib,{{ .Values.drivers.jdbcDriversPath }}
 - name: SPRING_PROFILES_ACTIVE
   value: engine
 - name: SPRING_PROFILES_INCLUDE
   value: kubernetes
 - name: SPRING_CLOUD_KUBERNETES_SECRETS_PATHS
   value: /etc/secrets
 - name: ks
   value: /etc/secrets/keystore
 - name: ksp
   value: /etc/secrets/keystore
  {{- if .Values.timeZone }}
 - name: TZ
   value: {{ .Values.timeZone }}
   {{- end }}
{{- range $key, $value := $.Values.extraEnv.normal }}
 - name: {{ $key }}
   value: {{ $value | quote }}
{{- end }}

{{- if .Values.extraEnv.secrets }}
    {{ toYaml .Values.extraEnv.secrets | nindent 1}}
 {{- end }}
{{- end }}

{{/*
Define Volume mounts
*/}}

{{- define "workervolumemounts" -}}
volumeMounts:
 - name: additional-properties-volume
   mountPath: /etc/config
 - name: adhoc-worker-secrets-volume
   mountPath: /etc/secrets
 - name: keystore-secret
   mountPath: /etc/secrets/keystore
 - name: drivers-volume
   mountPath: {{ .Values.drivers.jdbcDriversPath }}
    {{- if .Values.extraVolumeMounts }}
    {{ toYaml .Values.extraVolumeMounts | nindent 1}}
    {{- end }}
{{- end -}}

{{/*
Define Volumes
*/}}
{{- define "workervolumes" -}}
volumes:
  - name: additional-properties-volume
    configMap:
      name: {{ include "queryEngine.fullname" . }}-additional
  - name: adhoc-worker-secrets-volume
    secret:
      secretName: {{ default "adhoc-worker-credentials" .Values.appCredentialsSecretName }}
  - name: keystore-secret
    secret:
      secretName: {{ include "queryEngine.fullname" . }}
  - name: drivers-volume
    persistentVolumeClaim:
      claimName: {{ include "queryEngine.fullname" . }}
{{- if .Values.extraVolumes }}
    {{ toYaml .Values.extraVolumes | nindent 2}}
{{- end }}
{{- end -}}

{{/*
Define health check
*/}}

{{- define "workerhealthcheck" -}}
{{- if eq .Values.healthcheck.enabled true }}
livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    httpHeaders:
      - name: Host
        value: locahost
    port: {{ .Values.healthcheck.livenessProbe.port }}
  initialDelaySeconds: {{ .Values.healthcheck.livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.healthcheck.livenessProbe.periodSeconds }}
  failureThreshold: {{ .Values.healthcheck.livenessProbe.failureThreshold }}
  timeoutSeconds: {{ .Values.healthcheck.livenessProbe.timeoutSeconds }}
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    httpHeaders:
     - name: Host
       value: locahost
    port: {{ .Values.healthcheck.readinessProbe.port }}
  initialDelaySeconds: {{ .Values.healthcheck.readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.healthcheck.readinessProbe.periodSeconds }}
  failureThreshold: {{ .Values.healthcheck.readinessProbe.failureThreshold }}
  timeoutSeconds: {{ .Values.healthcheck.readinessProbe.timeoutSeconds }}
{{- end }}
{{- end -}}

{{- define "workerresources" -}}
{{- if eq .Values.resources.enabled true }}
resources:
  limits:
    cpu: {{ .Values.resources.limits.cpu }}
    memory: {{ .Values.resources.limits.memory }}
  requests:
    cpu: {{ .Values.resources.requests.cpu }}
    memory: {{ .Values.resources.requests.memory }}
{{- end }}
{{- end -}}

{{/*
Define Service account
*/}}

{{- define "workerserviceaccount" -}}
serviceAccountName: {{ .Values.serviceAccount.name }}
{{- end -}}

{{/*
Define security context
*/}}

{{- define "workersecuritycontext" -}}
securityContext:
  {{ toYaml .Values.securityContext | nindent 2 }}
{{- end -}}

{{/*
Define Redis configuration
*/}}

{{- define "redisconfiguration" -}}

{{- if and .Values.rediscluster.enabled (not .Values.rediscluster.externalRedisClusteraddress) -}}
nodeAddresses:
 - "redis://{{ .Release.Name }}-query-engine-redis-cluster:6379"
password: {{ .Values.global.redis.password }}
pingConnectionInterval: 7000
subscriptionsPerConnection: 7
subscriptionConnectionPoolSize: 30
 {{- else if .Values.rediscluster.externalRedisClusteraddress }}
nodeAddresses:
 - {{ .Values.rediscluster.externalRedisClusteraddress }}
password: {{ .Values.rediscluster.externalRedisClusterpassword }}
pingConnectionInterval: 7000
subscriptionsPerConnection: 7
subscriptionConnectionPoolSize: 30
{{- end -}}

{{- end -}}

{{- define "ingressannotations" -}}
haproxy.org/ingress.class: {{ .Values.ingressClass | quote }}
haproxy.org/path-rewrite: /query-engine/(.*) /\1
haproxy.org/cookie-persistence: "ADHOCLB"
{{- if .Values.ingress.annotations }}
{{ toYaml .Values.ingress.annotations }}
{{- end }}
{{- end -}}

{{- define "initcontainerconfig" -}}
- name: redis-connection
  image: alpine:3.11.6
  command: ["sh" , "-c" ,"until nc -vz {{ .Release.Name }}-query-engine-redis-cluster 6379; do echo waiting for redis at {{ .Release.Name }}-query-engine-redis-cluster:6379; sleep 2; done; echo connected to redis at {{ .Release.Name }}-query-engine-redis-cluster:6379"]
{{- end -}}