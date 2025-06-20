{{/*
Expand the name of the chart.
*/}}
{{- define "stalwart-mail-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "stalwart-mail-server.fullname" -}}
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
{{- define "stalwart-mail-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "stalwart-mail-server.labels" -}}
helm.sh/chart: {{ include "stalwart-mail-server.chart" . }}
{{ include "stalwart-mail-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: stalwart-mail-server
{{- if .Values.global.profile }}
stalwart.io/profile: {{ .Values.global.profile }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "stalwart-mail-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "stalwart-mail-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "stalwart-mail-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "stalwart-mail-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the config storage PVC
*/}}
{{- define "stalwart-mail-server.configPvcName" -}}
{{- printf "%s-config" (include "stalwart-mail-server.fullname" .) }}
{{- end }}

{{/*
Create the name of the data storage PVC
*/}}
{{- define "stalwart-mail-server.dataPvcName" -}}
{{- printf "%s-data" (include "stalwart-mail-server.fullname" .) }}
{{- end }}

{{/*
Create the name of the secret
*/}}
{{- define "stalwart-mail-server.secretName" -}}
{{- printf "%s-secret" (include "stalwart-mail-server.fullname" .) }}
{{- end }}

{{/*
Create the name of the configmap
*/}}
{{- define "stalwart-mail-server.configMapName" -}}
{{- printf "%s-config" (include "stalwart-mail-server.fullname" .) }}
{{- end }}

{{/*
Get replica count (simplified - uses direct values)
*/}}
{{- define "stalwart-mail-server.replicaCount" -}}
{{- .Values.stalwart.replicaCount }}
{{- end }}

{{/*
Get deployment strategy (simplified - uses direct values)
*/}}
{{- define "stalwart-mail-server.strategy" -}}
{{- toYaml .Values.stalwart.strategy }}
{{- end }}

{{/*
Get resources (simplified - uses direct values)
*/}}
{{- define "stalwart-mail-server.resources" -}}
{{- toYaml .Values.stalwart.resources }}
{{- end }}

{{/*
Get pod anti-affinity configuration
*/}}
{{- define "stalwart-mail-server.podAntiAffinity" -}}
{{- if .Values.stalwart.podAntiAffinity.enabled }}
{{- if eq .Values.stalwart.podAntiAffinity.type "requiredDuringSchedulingIgnoredDuringExecution" }}
requiredDuringSchedulingIgnoredDuringExecution:
- labelSelector:
    matchExpressions:
    - key: app.kubernetes.io/name
      operator: In
      values:
      - {{ include "stalwart-mail-server.name" . }}
    - key: app.kubernetes.io/instance
      operator: In
      values:
      - {{ .Release.Name }}
  topologyKey: {{ .Values.stalwart.podAntiAffinity.topologyKey | default "kubernetes.io/hostname" }}
{{- else if eq .Values.stalwart.podAntiAffinity.type "preferredDuringSchedulingIgnoredDuringExecution" }}
preferredDuringSchedulingIgnoredDuringExecution:
- weight: {{ .Values.stalwart.podAntiAffinity.weight | default 100 }}
  podAffinityTerm:
    labelSelector:
      matchExpressions:
      - key: app.kubernetes.io/name
        operator: In
        values:
        - {{ include "stalwart-mail-server.name" . }}
      - key: app.kubernetes.io/instance
        operator: In
        values:
        - {{ .Release.Name }}
    topologyKey: {{ .Values.stalwart.podAntiAffinity.topologyKey | default "kubernetes.io/hostname" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Check if PostgreSQL HA is enabled
*/}}
{{- define "stalwart-mail-server.postgresql-ha.enabled" -}}
{{- index .Values "postgresql-ha" "enabled" }}
{{- end }}

{{/*
Check if Redis is enabled
*/}}
{{- define "stalwart-mail-server.redis.enabled" -}}
{{- .Values.redis.enabled }}
{{- end }}

{{/*
Get PostgreSQL connection string
*/}}
{{- define "stalwart-mail-server.postgresql.connectionString" -}}
{{- if eq (include "stalwart-mail-server.postgresql-ha.enabled" .) "true" }}
{{- $username := index .Values "postgresql-ha" "postgresql" "auth" "username" | default "stalwart" }}
{{- $database := index .Values "postgresql-ha" "postgresql" "auth" "database" | default "stalwart" }}
{{- printf "postgresql://%s:${POSTGRES_PASSWORD}@%s-postgresql-ha-pgpool:5432/%s" $username .Release.Name $database }}
{{- else }}
{{- printf "postgresql://stalwart:${POSTGRES_PASSWORD}@localhost:5432/stalwart" }}
{{- end }}
{{- end }}

{{/*
Get Redis connection string
*/}}
{{- define "stalwart-mail-server.redis.connectionString" -}}
{{- if eq (include "stalwart-mail-server.redis.enabled" .) "true" }}
{{- if .Values.redis.sentinel.enabled }}
{{- printf "redis+sentinel://%s-redis:26379/mymaster" .Release.Name }}
{{- else }}
{{- printf "redis://%s-redis-master:6379" .Release.Name }}
{{- end }}
{{- else }}
{{- printf "" }}
{{- end }}
{{- end }}

{{/*
Generate Stalwart configuration based on dependencies
*/}}
{{- define "stalwart-mail-server.configuration" -}}
[server]
hostname = {{ .Values.config.hostname | default "mail.example.com" | quote }}

[cluster]
node-id = {{ .Values.config.nodeId | default 1 }}
{{- if eq (include "stalwart-mail-server.redis.enabled" .) "true" }}
coordinator = "redis"
{{- end }}

{{- if eq (include "stalwart-mail-server.postgresql-ha.enabled" .) "true" }}
[store."data"]
type = "postgresql"
url = {{ include "stalwart-mail-server.postgresql.connectionString" . | quote }}

[store."blob"]
type = "postgresql"
url = {{ include "stalwart-mail-server.postgresql.connectionString" . | quote }}

[store."fts"]
type = "postgresql"
url = {{ include "stalwart-mail-server.postgresql.connectionString" . | quote }}

[store."lookup"]
type = "postgresql"
url = {{ include "stalwart-mail-server.postgresql.connectionString" . | quote }}
{{- else }}
[store."data"]
type = "filesystem"
path = "/opt/stalwart-mail/data"

[store."blob"]
type = "filesystem"
path = "/opt/stalwart-mail/blobs"

[store."fts"]
type = "filesystem"
path = "/opt/stalwart-mail/fts"

[store."lookup"]
type = "filesystem"
path = "/opt/stalwart-mail/lookup"
{{- end }}

{{- if eq (include "stalwart-mail-server.redis.enabled" .) "true" }}
[store."redis"]
type = "redis"
url = {{ include "stalwart-mail-server.redis.connectionString" . | quote }}

[store."in-memory"]
type = "redis"
url = {{ include "stalwart-mail-server.redis.connectionString" . | quote }}
{{- else }}
[store."in-memory"]
type = "memory"
{{- end }}

# Additional configuration can be added here
{{- if .Values.config.content }}
{{ .Values.config.content }}
{{- end }}
{{- end }}

{{/*
Generate image name with tag
*/}}
{{- define "stalwart-mail-server.image" -}}
{{- $registry := .Values.stalwart.image.registry | default .Values.global.imageRegistry }}
{{- $repository := .Values.stalwart.image.repository }}
{{- $tag := .Values.stalwart.image.tag | default .Chart.AppVersion }}
{{- if $registry }}
{{- printf "%s/%s:%s" $registry $repository $tag }}
{{- else }}
{{- printf "%s:%s" $repository $tag }}
{{- end }}
{{- end }}
{{/*
Validate configuration
*/}}
{{- define "stalwart-mail-server.validateConfig" -}}
{{- /* Configuration validation can be added here */ -}}
{{- if not .Values.config.hostname -}}
{{- fail "config.hostname is required" -}}
{{- end -}}
{{- if not .Values.stalwart.image.repository -}}
{{- fail "stalwart.image.repository is required" -}}
{{- end -}}
{{- end }}
