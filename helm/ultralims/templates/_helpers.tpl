{{/*
Expand the name of the chart.
*/}}
{{- define "ultralims.name" -}}
{{- default .Chart.Name .Values.web.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ultralims.fullname" -}}
{{- if .Values.web.fullnameOverride }}
{{- .Values.web.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.web.nameOverride }}
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
{{- define "ultralims.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ultralims.labels" -}}
helm.sh/chart: {{ include "ultralims.chart" . }}
{{ include "ultralims.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "ultralims.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ultralims.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "ultralims.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "ultralims.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
ImportaResultado handlers
*/}}

{{/*
ImportaResultado name
*/}}
{{- define "ultralims.importaResultado.name" -}}
{{- printf "%s-import" ( default .Chart.Name .Values.importaResultado.nameOverride | trunc 56 | trimSuffix "-" ) }}
{{- end }}

{{/*
ImportaResultado fullName
*/}}
{{- define "ultralims.importaResultado.fullname" -}}
{{- if .Values.importaResultado.fullnameOverride }}
{{- .Values.importaResultado.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.importaResultado.nameOverride }}
{{- if contains $name .Release.Name }}
{{- printf "%s-import" ( .Release.Name | trunc 56 | trimSuffix "-" ) }}
{{- else }}
{{- printf "%s-%s-import" .Release.Name $name | trunc 56 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
ImportaResultado Common labels
*/}}
{{- define "ultralims.importaResultado.labels" -}}
helm.sh/chart: {{ include "ultralims.chart" . }}
{{ include "ultralims.importaResultado.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
ImportaResultado Selector labels
*/}}
{{- define "ultralims.importaResultado.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ultralims.importaResultado.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
