{{/*
Expand the name of the chart.
*/}}
{{- define "hedgedoc.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars per DNS naming spec.
If the release name already contains the chart name, the chart name is omitted.
*/}}
{{- define "hedgedoc.fullname" -}}
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
Create chart name-version as used by the chart label.
*/}}
{{- define "hedgedoc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels attached to every resource.
*/}}
{{- define "hedgedoc.labels" -}}
helm.sh/chart: {{ include "hedgedoc.chart" . }}
{{ include "hedgedoc.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels used in Deployment and Service.
*/}}
{{- define "hedgedoc.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hedgedoc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the ServiceAccount name to use.
*/}}
{{- define "hedgedoc.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hedgedoc.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the name of the Secret used by HedgeDoc.
Uses existingSecret if set, otherwise the generated "<fullname>-secret".
*/}}
{{- define "hedgedoc.secretName" -}}
{{- if .Values.existingSecret -}}
{{- .Values.existingSecret -}}
{{- else -}}
{{- printf "%s-secret" (include "hedgedoc.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Return the name of the ConfigMap used by HedgeDoc.
Uses existingConfigMap if set, otherwise the generated "<fullname>-config".
*/}}
{{- define "hedgedoc.configMapName" -}}
{{- if .Values.existingConfigMap -}}
{{- .Values.existingConfigMap -}}
{{- else -}}
{{- printf "%s-config" (include "hedgedoc.fullname" .) -}}
{{- end -}}
{{- end }}

{{/*
Return the internal PostgreSQL primary service hostname (bitnami sub-chart).
Bitnami/postgresql creates a ClusterIP service named "<release>-postgresql".
*/}}
{{- define "hedgedoc.postgresql.host" -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end }}

{{/*
Construct CMD_DB_URL from values.
Called only from secret.yaml (guarded by "if not .Values.existingSecret").

Branch 1 — internal PostgreSQL (bitnami sub-chart):
  Connection string: postgresql://<user>:<pass>@<release>-postgresql:5432/<db>

Branch 2 — external PostgreSQL:
  Connection string: postgresql://<user>:<pass>@<host>:<port>/<db>

IMPORTANT: Passwords that contain URL-reserved characters (@, /, :, ?, #, %)
must be percent-encoded or supplied via existingSecret (recommended for
production). The required() calls below produce clear error messages at
helm install/upgrade time if mandatory values are missing.
*/}}
{{- define "hedgedoc.databaseUrl" -}}
{{- if .Values.postgresql.enabled -}}
  {{- $host := include "hedgedoc.postgresql.host" . -}}
  {{- $user := .Values.postgresql.auth.username | required "postgresql.auth.username is required" -}}
  {{- $pass := .Values.postgresql.auth.password | required "postgresql.auth.password is required when postgresql.enabled=true and existingSecret is not set" -}}
  {{- $db   := .Values.postgresql.auth.database | required "postgresql.auth.database is required" -}}
  {{- printf "postgresql://%s:%s@%s:5432/%s" $user $pass $host $db -}}
{{- else -}}
  {{- $host := .Values.externalDatabase.host | required "externalDatabase.host is required when postgresql.enabled=false" -}}
  {{- $port := .Values.externalDatabase.port | toString -}}
  {{- $user := .Values.externalDatabase.username | required "externalDatabase.username is required when postgresql.enabled=false" -}}
  {{- $pass := .Values.externalDatabase.password | required "externalDatabase.password is required when postgresql.enabled=false and existingSecret is not set" -}}
  {{- $db   := .Values.externalDatabase.database | required "externalDatabase.database is required when postgresql.enabled=false" -}}
  {{- printf "postgresql://%s:%s@%s:%s/%s" $user $pass $host $port $db -}}
{{- end -}}
{{- end }}
