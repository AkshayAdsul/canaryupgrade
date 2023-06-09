{{- define "ratelimit.upstreamSpec" -}}
{{- $name := (index . 1) }}
{{- with (first .) }}
{{- $rateLimitName := .Values.global.extensions.rateLimit.service.name }}
{{- if .Values.global.extensions.dataplanePerProxy }}
{{- $rateLimitName = printf "%s-%s" $rateLimitName ($name | kebabcase) }}
{{- end }}{{/* .Values.global.extensions.dataplanePerProxy */}}
apiVersion: gloo.solo.io/v1
kind: Upstream
metadata:
  name: {{ $rateLimitName }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: gloo
    gloo: {{ $rateLimitName }}
spec:
  healthChecks:
  - timeout: 5s
    interval: 1m
    unhealthyThreshold: 5
    healthyThreshold: 5
    grpcHealthCheck:
      serviceName: ratelimit
  kube:
    serviceName: {{ $rateLimitName }}
    serviceNamespace: {{ .Release.Namespace }}
    servicePort:  {{ .Values.global.extensions.rateLimit.service.port }}
    serviceSpec:
      grpc: {}
---
{{- end }}{{/* with (first .) */}}
{{- end }}{{/* define "ratelimit.upstreamSpec" */}}

{{- define "glooe.customResources.ratelimitUpstreams" -}}
{{- if .Values.global.extensions.rateLimit.enabled }}
{{- include "gloo.dataplaneperproxyhelper" $ }}
{{- $override := dict -}}
{{- if .Values.global.extensions.rateLimit.upstream }}
{{- $override = .Values.global.extensions.rateLimit.upstream.kubeResourceOverride}}
{{- end }}{{/* if .Values.global.extensions.rateLimit.upstream */}}
{{- range $name, $spec := $.ProxiesToCreateDataplaneFor }}
{{- if not $spec.disabled}}
{{- $ctx := (list $ $name $spec)}}
{{ include "gloo.util.merge" (list $ctx $override "ratelimit.upstreamSpec") -}}
{{- end }}{{/* if not $spec.disabled */}}
{{- end }}{{/* range $name, $spec := $.ProxiesToCreateDataplaneFor */}}
{{- end }}{{/* .Values.global.extensions.rateLimit.enabled */}}
{{- end }}{{/* define "glooe.customResources.ratelimitUpstreams" */}}
