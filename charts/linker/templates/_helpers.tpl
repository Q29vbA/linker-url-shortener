{{/*
Expand the name of the chart.
*/}}
{{- define "linker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 characters because some Kubernetes name fields (due to DNS naming spec) have that limit.
If release name contains chart name it will be used as a full name.
*/}}
{{- define "linker.fullname" -}}
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
Create chart label, used for the helm.sh/chart annotation.
*/}}
{{- define "linker.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to all resources created by this chart.
*/}}
{{- define "linker.labels" -}}
helm.sh/chart: {{ include "linker.chart" . }}
{{ include "linker.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels -- used by Service and Deployment to find each other.
These must remain stable and should NOT include version or chart revision.
*/}}
{{- define "linker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "linker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}