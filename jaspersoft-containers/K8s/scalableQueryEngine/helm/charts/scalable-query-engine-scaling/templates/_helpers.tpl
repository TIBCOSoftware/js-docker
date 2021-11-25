{{/*
Expand the name of the chart.
*/}}
{{- define "scalableQueryEngineScaling.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "scalableQueryEngineScaling.fullname" -}}
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
define scalable query engine deployment name
*/}}

{{- define "scalableQueryEngineDeploymentName" -}}
{{- printf "%s-%s" .Release.Name  .Values.queryEngine.deployment  | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end -}}
{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "scalableQueryEngineScaling.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "scalableQueryEngineScaling.labels" -}}
helm.sh/chart: {{ include "scalableQueryEngineScaling.chart" . }}
{{ include "scalableQueryEngineScaling.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "scalableQueryEngineScaling.selectorLabels" -}}
app.kubernetes.io/name: {{ include "scalableQueryEngineScaling.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
