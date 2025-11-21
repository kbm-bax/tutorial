{{/*
Expand the name of the chart.
*/}}
{{- define "datalakehouse.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "datalakehouse.fullname" -}}
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
{{- define "datalakehouse.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "datalakehouse.labels" -}}
helm.sh/chart: {{ include "datalakehouse.chart" . }}
{{ include "datalakehouse.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "datalakehouse.selectorLabels" -}}
app.kubernetes.io/name: {{ include "datalakehouse.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "datalakehouse.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "datalakehouse.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
MinIO labels
*/}}
{{- define "datalakehouse.minio.labels" -}}
{{ include "datalakehouse.labels" . }}
app.kubernetes.io/component: minio
{{- end }}

{{/*
MinIO selector labels
*/}}
{{- define "datalakehouse.minio.selectorLabels" -}}
{{ include "datalakehouse.selectorLabels" . }}
app.kubernetes.io/component: minio
{{- end }}

{{/*
Jupyter labels
*/}}
{{- define "datalakehouse.jupyter.labels" -}}
{{ include "datalakehouse.labels" . }}
app.kubernetes.io/component: jupyter
{{- end }}

{{/*
Jupyter selector labels
*/}}
{{- define "datalakehouse.jupyter.selectorLabels" -}}
{{ include "datalakehouse.selectorLabels" . }}
app.kubernetes.io/component: jupyter
{{- end }}