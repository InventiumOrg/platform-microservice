{{/*
Expand the name of the service.
Centralized chart: the chart name is the same for every service, so the name
comes from `nameOverride` and falls back to the release name.
*/}}
{{- define "platform-microservice.name" -}}
{{- default .Release.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec).
*/}}
{{- define "platform-microservice.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- include "platform-microservice.name" . }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "platform-microservice.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Namespace for every rendered object.
*/}}
{{- define "platform-microservice.namespace" -}}
{{- default .Release.Namespace .Values.namespace }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "platform-microservice.labels" -}}
helm.sh/chart: {{ include "platform-microservice.chart" . }}
{{ include "platform-microservice.selectorLabels" . }}
{{- if or .Values.image.tag .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | toString | replace "+" "_" | trunc 63 | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "platform-microservice.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform-microservice.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Annotations added to every rendered object.
*/}}
{{- define "platform-microservice.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "platform-microservice.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "platform-microservice.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Object names derived from the fullname.
*/}}
{{- define "platform-microservice.configMapName" -}}
{{- printf "%s-config" (include "platform-microservice.fullname" .) }}
{{- end }}

{{- define "platform-microservice.secretName" -}}
{{- printf "%s-secrets" (include "platform-microservice.fullname" .) }}
{{- end }}

{{- define "platform-microservice.secretFilesName" -}}
{{- if .Values.secretFiles.existingSecret }}
{{- .Values.secretFiles.existingSecret }}
{{- else }}
{{- printf "%s-files" (include "platform-microservice.fullname" .) }}
{{- end }}
{{- end }}

{{- define "platform-microservice.otelConfigMapName" -}}
{{- printf "%s-otel-config" (include "platform-microservice.fullname" .) }}
{{- end }}

{{/*
Container image reference.
*/}}
{{- define "platform-microservice.image" -}}
{{- $repository := required "image.repository is required" .Values.image.repository }}
{{- printf "%s:%s" $repository (.Values.image.tag | default .Chart.AppVersion | toString) }}
{{- end }}

{{/*
Normalize imagePullSecrets. Accepts a plain string ("ecr-registry-secret"),
a list of strings, or the Kubernetes list-of-maps form.
*/}}
{{- define "platform-microservice.imagePullSecrets" -}}
{{- $secrets := list }}
{{- $value := .Values.imagePullSecrets }}
{{- if kindIs "string" $value }}
{{- if $value }}{{ $secrets = append $secrets (dict "name" $value) }}{{ end }}
{{- else if kindIs "slice" $value }}
{{- range $value }}
{{- if kindIs "string" . }}
{{- $secrets = append $secrets (dict "name" .) }}
{{- else if .name }}
{{- $secrets = append $secrets . }}
{{- end }}
{{- end }}
{{- end }}
{{- with $secrets }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
envFrom sources for the application container: the chart-managed ConfigMap and
Secret (when they hold anything), then any externally managed ones.
*/}}
{{- define "platform-microservice.envFrom" -}}
{{- if .Values.config }}
- configMapRef:
    name: {{ include "platform-microservice.configMapName" . }}
{{- end }}
{{- if .Values.secrets }}
- secretRef:
    name: {{ include "platform-microservice.secretName" . }}
{{- end }}
{{- range .Values.existingConfigMaps }}
- configMapRef:
    name: {{ . }}
{{- end }}
{{- range .Values.existingSecrets }}
- secretRef:
    name: {{ . }}
{{- end }}
{{- with .Values.extraEnvFrom }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Container ports: the primary service port plus any extras.
*/}}
{{- define "platform-microservice.containerPorts" -}}
- name: {{ .Values.service.name | default "http" }}
  containerPort: {{ required "service.port is required" .Values.service.port }}
  protocol: {{ .Values.service.protocol | default "TCP" }}
{{- with .Values.extraContainerPorts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
volumeMounts shared by the application container.
*/}}
{{- define "platform-microservice.volumeMounts" -}}
{{- if .Values.logging.enabled }}
- name: logs
  mountPath: {{ .Values.logging.logPath }}
{{- end }}
{{- if .Values.secretFiles.enabled }}
- name: secret-files
  mountPath: {{ .Values.secretFiles.mountPath }}
  readOnly: true
{{- end }}
{{- if and .Values.configMount.enabled .Values.config }}
- name: config
  mountPath: {{ .Values.configMount.mountPath }}
  readOnly: true
{{- end }}
{{- with .Values.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Pod volumes.
*/}}
{{- define "platform-microservice.volumes" -}}
{{- if .Values.logging.enabled }}
- name: logs
  emptyDir: {}
- name: otel-collector-config
  configMap:
    name: {{ include "platform-microservice.otelConfigMapName" . }}
{{- end }}
{{- if .Values.secretFiles.enabled }}
- name: secret-files
  secret:
    secretName: {{ include "platform-microservice.secretFilesName" . }}
    optional: false
{{- end }}
{{- if and .Values.configMount.enabled .Values.config }}
- name: config
  configMap:
    name: {{ include "platform-microservice.configMapName" . }}
{{- end }}
{{- with .Values.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}
