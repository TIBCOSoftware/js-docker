{{/*
Expand the name of the chart.
*/}}
{{- define "jrs.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{- define "jms.name" -}}
{{- default .Chart.Name .Values.jms.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "jrs.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "jrs.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "jrs.labels" -}}
helm.sh/chart: {{ include "jrs.chart" . }}
{{ include "jrs.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "jrs.selectorLabels" -}}
app.kubernetes.io/name: {{ include "jrs.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "jrs.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "jrs.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}


{{/*
Define env varibales here
*/}}

{{- define "env" -}}
env:
{{- if and .Values.jms.enabled  (not .Values.jms.jmsBrokerUrl) }}
 - name: JAVA_OPTS
   value: " {{ .Values.extraEnv.javaOpts}}  -Djs.license.directory=/usr/local/share/jasperserver-pro/license -Djasperserver.cache.jms.provider=tcp://jasperserver-cache-service.{{.Release.Namespace}}.svc.cluster.local:61616"
{{- else if  .Values.jms.jmsBrokerUrl }}
 - name: JAVA_OPTS
   value: " {{ .Values.extraEnv.javaOpts}}  -Djs.license.directory=/usr/local/share/jasperserver-pro/license -Djasperserver.cache.jms.provider={{ .Values.jms.jmsBrokerUrl }}"
{{ else }}
 - name: JAVA_OPTS
   value: "{{ .Values.extraEnv.javaOpts}} -Djs.license.directory=/usr/local/share/jasperserver-pro/license"
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
Define security context
*/}}

{{- define "securitycontext" -}}
securityContext:
  {{ toYaml .Values.securityContext | nindent 2 }}
{{- end -}}


{{/*
Define security context
*/}}

{{- define "jmssecuritycontext" -}}
securityContext:
  {{ toYaml .Values.jms.securityContext | nindent 2 }}
{{- end -}}


{{/*
Define tolerations
*/}}
{{- define "tolerations" -}}
{{- if .Values.tolerations }}
tolerations:
 {{ toYaml .Values.tolerations | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Define Node Affinity
*/}}
{{- define "affinity" -}}
{{- if .Values.affinity }}
affinity:
  nodeAffinity:
 {{ toYaml .Values.affinity | nindent 4 }}
{{- end }}
{{- end -}}


{{/*
Define Volume mounts
*/}}

{{- define "volumemounts" -}}
volumeMounts:

  - mountPath: /usr/local/share/jasperserver-pro/license
    name: jasperserver-license
    readOnly: true

  - mountPath: /usr/local/share/jasperserver-pro/keystore
    name: jasperserver-keystore
    readOnly: true
    {{- if .Values.extraVolumeMounts }}
    {{ toYaml .Values.extraVolumeMounts | nindent 2}}
    {{- end }}
{{- end -}}

{{/*
Define Volumes
*/}}
{{- define "volumes" -}}
volumes:
  - name: jasperserver-license
    secret:
      secretName: {{ .Values.secretLicenseName }}
  - name: jasperserver-keystore
    secret:
      secretName: {{ .Values.secretKeyStoreName }}
{{- if .Values.extraVolumes }}
    {{ toYaml .Values.extraVolumes | nindent 2}}
{{- end }}
{{- end -}}


{{/*
Define Volume mounts
*/}}

{{- define "buildomaticvolumemounts" -}}
volumeMounts:
  - mountPath: /usr/local/share/jasperserver-pro/keystore
    name: jasperserver-keystore
    readOnly: true
{{- end -}}

{{/*
Define Service account
*/}}

{{- define "serviceaccountname" -}}
serviceAccountName: {{ .Values.serviceAccount.name }}
{{- end -}}

{{/*
Define buildomatic Volumes
*/}}
{{- define "buildomaticvolumes" -}}
volumes:
  - name: jasperserver-keystore
    secret:
      secretName: {{ .Values.secretKeyStoreName }}
{{- end -}}


{{/*
Define health check
*/}}

{{- define "healthcheck" -}}
{{- if eq .Values.healthcheck.enabled true }}
livenessProbe:
  httpGet:
    path: /jasperserver-pro/login.html
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
    path: /jasperserver-pro/login.html
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


{{/*
Define jms health check
*/}}

{{- define "jmshealthcheck" -}}
{{- if eq .Values.jms.healthcheck.enabled true }}
livenessProbe:
  tcpSocket:
    port: {{ .Values.jms.healthcheck.livenessProbe.port }}
  initialDelaySeconds: {{ .Values.jms.healthcheck.livenessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.jms.healthcheck.livenessProbe.periodSeconds }}
  failureThreshold: {{ .Values.jms.healthcheck.livenessProbe.failureThreshold }}

readinessProbe:
  tcpSocket:
    port: {{ .Values.jms.healthcheck.livenessProbe.port }}
  initialDelaySeconds: {{ .Values.jms.healthcheck.readinessProbe.initialDelaySeconds }}
  periodSeconds: {{ .Values.jms.healthcheck.readinessProbe.periodSeconds }}
  failureThreshold: {{ .Values.jms.healthcheck.readinessProbe.failureThreshold }}
{{- end }}

{{- end -}}


{{- define "resources" -}}
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

{{- define "jmsresources" -}}
{{- if eq .Values.jms.resources.enabled true }}
resources:
  limits:
    cpu: {{ .Values.jms.resources.limits.cpu }}
    memory: {{ .Values.jms.resources.limits.memory }}
  requests:
    cpu: {{ .Values.jms.resources.requests.cpu }}
    memory: {{ .Values.jms.resources.requests.memory }}
{{- end }}
{{- end -}}


{{- define "js.ant.targets" -}}
{{- if eq .Values.buildomatic.includeSamples true }}
- "gen-config pre-install-test-pro prepare-all-pro-dbs-normal"
{{- else }}
- "set-minimal-mode gen-config pre-install-test-pro prepare-js-pro-db-minimal"
{{- end }}
{{- end -}}

