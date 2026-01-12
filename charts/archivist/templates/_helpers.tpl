{{/*
Expand the name of the chart.
*/}}
{{- define "archivist.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "archivist.fullname" -}}
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
Create chart namespace.
*/}}
{{- define "archivist.namespace" -}}
{{ default .Release.Namespace .Values.namespaceOverride }}
{{- end }}

{{/*
Create ingress name.
*/}}
{{- define "archivist.ingress.name" -}}
{{- if .Values.ingress.fullnameOverride }}
{{- .Values.ingress.fullnameOverride }}
{{- else }}
{{- include "archivist.fullname" . }}
{{- end }}
{{- end }}

{{- define "archivist.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "archivist.labels" -}}
helm.sh/chart: {{ include "archivist.chart" . }}
{{ include "archivist.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "archivist.selectorLabels" -}}
app.kubernetes.io/name: {{ include "archivist.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "archivist.serviceAccountName" -}}
{{- if eq (include "archivist.serviceAccount.create" .) "true" -}}
{{- default (include "archivist.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Role name.
*/}}
{{- define "archivist.clusterRole.name" -}}
{{ print (include "archivist.namespace" .) "-" (include "archivist.serviceAccountName" .) }}
{{- end }}

{{- define "archivist.role.name" -}}
{{ include "archivist.serviceAccountName" . }}
{{- end }}

{{/*
StatefulSets count.
*/}}
{{- define "archivist.statefulSetCount" -}}
{{- if eq (include "archivist.service.nodeport.enabled" .) "true" }}
{{- .Values.replica.count }}
{{- else }}
{{- 1 }}
{{- end }}
{{- end }}

{{/*
Replica count.
*/}}
{{- define "archivist.replica.count" -}}
{{- if eq (int (include "archivist.statefulSetCount" .)) 1 }}
{{- .Values.replica.count }}
{{- else }}
{{- 1 }}
{{- end }}
{{- end }}

{{/*
Enable NodePort service.
*/}}
{{- define "archivist.service.nodeport.enabled" -}}
{{- if has "nodeport" .Values.service.type }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
Enable initEnv container.
*/}}
{{- define "archivist.initEnv.enabled" -}}
{{- if .Values.initEnv.enabled }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
Create ServiceAccount.
*/}}
{{- define "archivist.serviceAccount.create" -}}
{{- if and (eq (include "archivist.initEnv.enabled" .) "true") .Values.serviceAccount.create }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
Create RBAC resources.
*/}}
{{- define "archivist.serviceAccount.rbac.create" -}}
{{- if and (eq (include "archivist.serviceAccount.create" .) "true") .Values.serviceAccount.rbac.create -}}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}

{{/*
Mount ARCHIVIST_ETH_PRIVATE_KEY.
*/}}
{{- define "archivist.env.ethPrivateKey.mount" -}}
{{- if and .Values.archivist.env.ARCHIVIST_PERSISTENCE .Values.archivist.env.ARCHIVIST_ETH_PRIVATE_KEY }}
{{- "true" }}
{{- else }}
{{- "false" }}
{{- end }}
{{- end }}
