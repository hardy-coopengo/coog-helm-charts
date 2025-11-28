{{/* vim: set filetype=mustache: */}}

{{/*
Expand the name of the chart.
*/}}
{{- define "general.names.name" -}}
{{- $tplDir := base (dir .Template.Name) -}}
{{- if or (eq "templates" $tplDir) (eq "coog" $tplDir) -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Chart.Name $tplDir | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "general.names.fullname" -}}
{{- $tplDir := base (dir .Template.Name) -}}
{{- if eq "templates" $tplDir -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s-%s" .Release.Name .Chart.Name $tplDir | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "general.names.short" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "general.names.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define general namespace
*/}}
{{- define "general.namespace" -}}
    {{- print .Release.Namespace -}}
{{- end -}}

{{/*
Kubernetes standard labels
*/}}
{{- define "general.labels.standard" -}}
app.kubernetes.io/name: {{ include "general.names.name" . }}
helm.sh/chart: {{ include "general.names.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{/*
Labels to use on deploy.spec.selector.matchLabels and svc.spec.selector
*/}}
{{- define "general.labels.matchLabels" -}}
app.kubernetes.io/name: {{ include "general.names.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Renders a value that contains template.
Usage:
{{ include "general.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "general.tplvalues.render" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context }}
{{- else }}
{{- tpl (.value | toYaml) .context }}
{{- end }}
{{- end -}}

{{/*
Return  the proper Storage Class
{{ include "storage.class" (dict "value" .Values.path.to.the.Value) | nindent X }}
*/}}
{{- define "storage.class" -}}
{{- $storageClass := .value -}}
{{- if $storageClass -}}
{{- if (eq "-" $storageClass) -}}
{{- printf "storageClassName: \"\"" -}}
{{- else }}
{{- printf "storageClassName: %s" $storageClass -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Generate tokens for some variables
Usage
{{- if not .Values.secrets.backCore.extraEnvVar.TRYTOND_SESSION__PASSPHRASE }}
TRYTOND_SESSION__PASSPHRASE: {{ include "secret.token.generator" (dict "value" "TRYTOND_SESSION__PASSPHRASE" "secretName" (printf "%s-backcore-configuration" (include "general.names.short" .))) | quote }}
{{- end }}
*/}}
{{- define "secret.token.generator" -}}
{{- $secretObj := (lookup "v1" "Secret" .namespace .secretName) | default dict -}}
{{- $secretData := (get $secretObj "data") | default dict -}}
{{- $secretValue := (get $secretData .key | b64dec) | default (randAlphaNum 32) -}}
{{ .key }}: {{ $secretValue | quote }}
{{- end -}}


{{/*
Join TRYTOND_DATABASE_NAMES in string format
*/}}
{{- define "postgres.databases" -}}
{{ .Values.postgresql.auth.database }}
{{- if .Values.backCore.extraDatabases }}
{{- $databases := list -}}
{{- range .Values.backCore.extraDatabases }}
{{- $databases = . | append $databases -}}
{{- end -}}
{{- printf ",%s" (join "," $databases) }}
{{- end -}}
{{- end -}}


{{/*
Join mongodb hosts in string format
*/}}
{{- define "mongodb.uri" -}}
{{- $replicaCount := int .Values.mongodb.replicaCount }}
{{- $portNumber := int .Values.mongodb.service.ports.mongodb }}
{{- $fullname := printf "%s-mongodb" .Release.Name }}
{{- $releaseNamespace := include "general.namespace" . }}
{{- $clusterDomain := .Values.clusterDomain }}
{{- $hosts := list -}}
{{- $options := list -}}
{{- $protocol := "mongodb://" -}}
{{- $srvEnabled := .Values.mongodb.srv_uri | default false -}}
{{- if $srvEnabled -}}
{{- $protocol = "mongodb+srv://" -}}
{{- end -}}
{{- range .Values.mongodb.uriOptions -}}
{{- $options = printf "%s" . | append $options -}}
{{- end -}}
{{- if .Values.mongodb.hosts -}}
{{- range .Values.mongodb.hosts -}}
{{- if $srvEnabled -}}
{{- $hosts = printf "%s" . | append $hosts -}}
{{- else -}}
{{- $hosts = printf "%s" . | append $hosts -}}
{{- end -}}
{{- end -}}
{{- printf "%s%s:%s@%s/%s" $protocol (first $.Values.mongodb.auth.usernames) (first $.Values.mongodb.auth.passwords) (join "," $hosts) (first $.Values.mongodb.auth.databases) }}
{{- else -}}
{{- if eq .Values.mongodb.architecture "replicaset" -}}
{{- range $e, $i := until $replicaCount }}
{{- if $srvEnabled -}}
{{- $hosts = printf "%s-%d.%s-headless.%s.svc.%s" $fullname $i $fullname $releaseNamespace $clusterDomain | append $hosts }}
{{- else -}}
{{- $hosts = printf "%s-%d.%s-headless.%s.svc.%s:%d" $fullname $i $fullname $releaseNamespace $clusterDomain $portNumber | append $hosts }}
{{- end -}}
{{- end }}
{{- printf "%s%s:%s@%s/%s?replicaSet=%s" $protocol (first .Values.mongodb.auth.usernames) (first .Values.mongodb.auth.passwords) (join "," $hosts) (first .Values.mongodb.auth.databases) .Values.mongodb.replicaSetName }}
{{- else -}}
{{- if $srvEnabled -}}
{{- printf "%s%s:%s@%s/%s" $protocol (first .Values.mongodb.auth.usernames) (first .Values.mongodb.auth.passwords) $fullname (first .Values.mongodb.auth.databases) }}
{{- else -}}
{{- printf "%s%s:%s@%s:%d/%s" $protocol (first .Values.mongodb.auth.usernames) (first .Values.mongodb.auth.passwords) $fullname $portNumber (first .Values.mongodb.auth.databases) }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if $options -}}
{{- printf "?%s" (join "?" $options) }}
{{- end -}}
{{- end -}}


{{/*
Create image pull secret string.
*/}}
{{- define "imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
Generate LibroConv API URI based on deployment mode (shared vs per-tenant)
Usage: {{ include "libroconv.uri" . }}
*/}}
{{- define "libroconv.uri" -}}
{{- $protocol := "http://" -}}
{{- $port := .Values.libroconv.externalPort | default 5000 | toString -}}
{{- $basePath := "/unoconv/{oext}" -}}
{{- $externalAddress := .Values.libroconv.externalAddress | default "" -}}
{{- $releaseNamespace := include "general.namespace" . -}}

{{- if and (not .Values.libroconv.enabled) .Values.libroconv.externalAddress -}}
{{- printf "%s%s:%s%s/%s" $protocol $externalAddress $port $basePath $releaseNamespace -}}
{{- else if .Values.libroconv.enabled -}}
{{- $serviceName := printf "%s-libroconv" (include "general.names.short" .) -}}
{{- printf "%s%s:%s%s" $protocol $serviceName $port $basePath -}}
{{- end -}}
{{- end -}}
