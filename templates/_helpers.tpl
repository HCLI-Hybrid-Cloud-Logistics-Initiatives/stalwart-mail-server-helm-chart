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
{{- if .Values.security.serviceAccount.create }}
{{- default (include "stalwart-mail-server.fullname" .) .Values.security.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.security.serviceAccount.name }}
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
Get the profile configuration
*/}}
{{- define "stalwart-mail-server.profileConfig" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- toYaml $profileConfig }}
{{- end }}

{{/*
Get replica count based on profile
*/}}
{{- define "stalwart-mail-server.replicaCount" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- if $profileConfig.stalwart.replicaCount }}
{{- $profileConfig.stalwart.replicaCount }}
{{- else }}
{{- .Values.stalwart.replicaCount }}
{{- end }}
{{- end }}

{{/*
Get deployment strategy based on profile
*/}}
{{- define "stalwart-mail-server.strategy" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- if $profileConfig.stalwart.strategy }}
{{- toYaml $profileConfig.stalwart.strategy }}
{{- else }}
{{- toYaml .Values.stalwart.strategy }}
{{- end }}
{{- end }}

{{/*
Get resources based on profile
*/}}
{{- define "stalwart-mail-server.resources" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- if $profileConfig.stalwart.resources }}
{{- toYaml $profileConfig.stalwart.resources }}
{{- else }}
{{- toYaml .Values.stalwart.resources }}
{{- end }}
{{- end }}

{{/*
Get anti-affinity configuration based on profile
*/}}
{{- define "stalwart-mail-server.podAntiAffinity" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- $antiAffinity := $profileConfig.stalwart.podAntiAffinity | default .Values.stalwart.podAntiAffinity }}
{{- if $antiAffinity.enabled }}
{{- if eq $antiAffinity.type "requiredDuringSchedulingIgnoredDuringExecution" }}
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
  topologyKey: {{ $antiAffinity.topologyKey | default "kubernetes.io/hostname" }}
{{- else if eq $antiAffinity.type "preferredDuringSchedulingIgnoredDuringExecution" }}
preferredDuringSchedulingIgnoredDuringExecution:
- weight: {{ $antiAffinity.weight | default 100 }}
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
    topologyKey: {{ $antiAffinity.topologyKey | default "kubernetes.io/hostname" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Get storage configuration based on profile
*/}}
{{- define "stalwart-mail-server.storageConfig" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- if $profileConfig.storage }}
{{- toYaml $profileConfig.storage }}
{{- else }}
{{- toYaml .Values.storage }}
{{- end }}
{{- end }}

{{/*
Check if PostgreSQL HA is enabled based on profile
*/}}
{{- define "stalwart-mail-server.postgresql-ha.enabled" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- if hasKey $profileConfig "postgresql-ha" }}
{{- $profileConfig.postgresql-ha.enabled }}
{{- else }}
{{- .Values.postgresql-ha.enabled }}
{{- end }}
{{- end }}

{{/*
Check if Redis is enabled based on profile
*/}}
{{- define "stalwart-mail-server.redis.enabled" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- $profileConfig := index .Values.profiles $profile }}
{{- if hasKey $profileConfig "redis" }}
{{- $profileConfig.redis.enabled }}
{{- else }}
{{- .Values.redis.enabled }}
{{- end }}
{{- end }}

{{/*
Get PostgreSQL connection string
*/}}
{{- define "stalwart-mail-server.postgresql.connectionString" -}}
{{- if eq (include "stalwart-mail-server.postgresql-ha.enabled" .) "true" }}
{{- printf "postgresql://%s:%s@%s-postgresql-ha-pgpool:5432/%s" .Values.postgresql-ha.postgresql.username .Values.postgresql-ha.postgresql.password .Release.Name .Values.postgresql-ha.postgresql.database }}
{{- else }}
{{- printf "postgresql://stalwart:stalwart@localhost:5432/stalwart" }}
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
Generate Stalwart configuration based on profile and dependencies
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
Generate network policy rules
*/}}
{{- define "stalwart-mail-server.networkPolicyRules" -}}
ingress:
{{- if not .Values.security.networkPolicies.denyAll }}
- {}
{{- else }}
# Allow traffic from same namespace
- from:
  - namespaceSelector:
      matchLabels:
        name: {{ .Release.Namespace }}
{{- if .Values.security.networkPolicies.allowNamespaces }}
# Allow traffic from specific namespaces
{{- range .Values.security.networkPolicies.allowNamespaces }}
- from:
  - namespaceSelector:
      matchLabels:
        name: {{ . }}
{{- end }}
{{- end }}
# Allow mail traffic on standard ports
- ports:
  - protocol: TCP
    port: 25
  - protocol: TCP
    port: 143
  - protocol: TCP
    port: 587
  - protocol: TCP
    port: 993
  - protocol: TCP
    port: 995
  - protocol: TCP
    port: 465
  - protocol: TCP
    port: 110
  - protocol: TCP
    port: 4190
# Allow admin interface
- ports:
  - protocol: TCP
    port: 8080
  - protocol: TCP
    port: 443
{{- if eq (include "stalwart-mail-server.postgresql-ha.enabled" .) "true" }}
# Allow PostgreSQL traffic
- from:
  - podSelector:
      matchLabels:
        app.kubernetes.io/name: postgresql-ha
  ports:
  - protocol: TCP
    port: 5432
{{- end }}
{{- if eq (include "stalwart-mail-server.redis.enabled" .) "true" }}
# Allow Redis traffic
- from:
  - podSelector:
      matchLabels:
        app.kubernetes.io/name: redis
  ports:
  - protocol: TCP
    port: 6379
  - protocol: TCP
    port: 26379
{{- end }}
{{- end }}
egress:
- {}
{{- end }}

{{/*
Validate configuration
*/}}
{{- define "stalwart-mail-server.validateConfig" -}}
{{- $profile := .Values.global.profile | default "small" }}
{{- if not (has $profile (list "tiny" "small" "medium" "large")) }}
{{- fail (printf "Invalid profile '%s'. Must be one of: tiny, small, medium, large" $profile) }}
{{- end }}
{{- $replicaCount := include "stalwart-mail-server.replicaCount" . | int }}
{{- if and (gt $replicaCount 1) (eq .Values.storage.pvc.accessMode "ReadWriteOnce") }}
{{- fail "Cannot use ReadWriteOnce access mode with multiple replicas. Use ReadWriteMany instead." }}
{{- end }}
{{- end }}