{{- define "taskmanager.labels" -}}
app.kubernetes.io/part-of: taskmanager
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}
