{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "gcloud-endpoints.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 24 -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 24 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}
{{- define "gcloud-endpoints.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 24 -}}
{{- end -}}

{{- define "gcloud-endpoints.toYaml" -}}
  {{- range $key, $value := . -}}
    {{- $map := kindIs "map" $value -}}
    {{- if $map }}
{{ $key }}:
  {{- include "gcloud-endpoints.toYaml" $value | indent 2 }}
    {{- else }}
{{ $key }}: {{ $value }}
    {{- end }}
  {{- end -}}
{{- end -}}
