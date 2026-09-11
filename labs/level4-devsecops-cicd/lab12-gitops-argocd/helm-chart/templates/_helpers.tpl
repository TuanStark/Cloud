{{/*
Tạo tên chuẩn hóa cho ứng dụng
*/}}
{{- define "payment-vault.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Tạo tên đầy đủ (Fullname) kết hợp release name và chart name
*/}}
{{- define "payment-vault.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name (include "payment-vault.name" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Bộ nhãn chuẩn hóa (Standard Kubernetes Labels)
*/}}
{{- define "payment-vault.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "payment-vault.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
environment: {{ .Values.environment | default "dev" }}
{{- end }}

{{/*
Selector labels dùng cho Deployment và Service
*/}}
{{- define "payment-vault.selectorLabels" -}}
app.kubernetes.io/name: {{ include "payment-vault.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
