{{/*
Fail fast on value combinations that would render invalid manifests.
Included from deployment.yaml so it runs on every `helm template`/`lint`.
*/}}
{{- define "platform-microservice.validate" -}}
{{- range .Values.volumes }}
{{- if le (len (keys .)) 1 }}
{{- fail (printf "volumes entry %q has no volume source. Give it one (secret/configMap/emptyDir/...), or use `secretFiles` to mount certificates and keys." (.name | default "<unnamed>")) }}
{{- end }}
{{- end }}
{{- if .Values.secretFiles.enabled }}
{{- if and (not .Values.secretFiles.files) (not .Values.secretFiles.existingSecret) }}
{{- fail "secretFiles.enabled is true but neither secretFiles.files nor secretFiles.existingSecret is set." }}
{{- end }}
{{- if and .Values.secretFiles.files .Values.secretFiles.existingSecret }}
{{- fail "secretFiles.files and secretFiles.existingSecret are mutually exclusive." }}
{{- end }}
{{- end }}
{{- if and .Values.podDisruptionBudget.enabled .Values.podDisruptionBudget.minAvailable .Values.podDisruptionBudget.maxUnavailable }}
{{- fail "podDisruptionBudget.minAvailable and podDisruptionBudget.maxUnavailable are mutually exclusive; set one to null." }}
{{- end }}
{{- if and .Values.autoscaling.enabled (lt (int .Values.autoscaling.maxReplicas) (int .Values.autoscaling.minReplicas)) }}
{{- fail "autoscaling.maxReplicas must be greater than or equal to autoscaling.minReplicas." }}
{{- end }}
{{- end }}
