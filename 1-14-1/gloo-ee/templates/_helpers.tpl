{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}

{{/* Used to update the values during the render of a template. Useful for taking user-friendly gloo-ee
     values and renaming them to gloo's expected format without leaking implementation details */}}
{{- define "gloo.updatevalues" -}}
{{- if .Values.global.extensions.extAuth.envoySidecar -}}
{{- $plugins := .Values.global.extensions.extAuth.plugins -}}
{{- range $proxyName, $proxy := .Values.gatewayProxies -}}
{{- $_ := set (index $.Values.gatewayProxies $proxyName) "extraContainersHelper" "gloo.extauthcontainer" -}}
{{- if $plugins -}}
{{- $_ = set (index $.Values.gatewayProxies $proxyName) "extraInitContainersHelper" "gloo.extauthinitcontainers" -}}
{{- $_ = set (index $.Values.gatewayProxies $proxyName) "extraVolumeHelper" "gloo.extauthpluginvolume" -}}
{{- end -}} {{/* if plugins */}}
{{- if $.Values.global.glooMtls.enabled }}
{{- $_ = set (index $.Values.gatewayProxies $proxyName) "extraListenersHelper" "gloo.sidecarlisteners" -}}
{{- end -}} {{/* end glooMtls.enabled */}}
{{- end -}} {{/* end range */}}
{{- end -}} {{/* if envoySidecar */}}
{{- end -}} {{/* end define */}}

{{/* Volume definition needed for ext auth plugin setup */}}
{{- define "gloo.extauthpluginvolume" -}}
- emptyDir: {}
  name: auth-plugins
{{- end -}}

{{/* Listener definition needed for ext auth setup */}}
{{- define "gloo.sidecarlisteners" -}}
- name: gloo_xds_mtls_listener
  address:
    socket_address:
      address: 127.0.0.1
      port_value: 9955
  filter_chains:
    - filters:
      - name: envoy.filters.network.tcp_proxy
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.tcp_proxy.v3.TcpProxy
          stat_prefix: gloo_mtls
          {{- if $.Values.k8s }}
          cluster: gloo.{{ $.Release.Namespace }}.svc.{{ $.Values.k8s.clusterName}}:{{ $.Values.gloo.deployment.xdsPort }}
          {{- else }}
          cluster: gloo.{{ $.Release.Namespace }}.svc.{{ $.Values.gloo.k8s.clusterName}}:{{ $.Values.gloo.gloo.deployment.xdsPort }}
          {{- end}}
{{- end -}}

{{/* Init container definition for extauth plugin setup */}}
{{- define "gloo.extauthinitcontainers" -}}
{{- $extAuth := $.Values.global.extensions.extAuth -}}
{{- range $name, $plugin := $extAuth.plugins -}}
{{- $pluginImage := merge $plugin.image $.Values.global.image -}}
- image: {{template "gloo.image" $pluginImage}}
  {{- if $pluginImage.pullPolicy }}
  imagePullPolicy: {{ $pluginImage.pullPolicy }}
  {{- end}}
  name: plugin-{{ $name }}
  volumeMounts:
    - name: auth-plugins
      mountPath: /auth-plugins
{{end}} {{/* don't strip the newline here for rendering purposes */}}
{{- end}}

{{/* Container definition for extauth, used in extauth deployment and
     gateway-proxy (envoy) sidecar over unix domain socket

     Expects both the keys Values and ExtAuthMode in its root context, with the latter
     taking either the value "sidecar" or "standalone". It will default to "sidecar"
     if the value is not provided. */}}
{{- define "gloo.extauthcontainer" -}}
{{- $extAuth := $.Values.global.extensions.extAuth -}}
{{- $image := $extAuth.deployment.image -}}
{{- $statsConfig := coalesce $extAuth.deployment.stats $.Values.global.glooStats -}}
{{- if $.Values.global -}}
{{- $image = merge $extAuth.deployment.image $.Values.global.image -}}
{{- end -}}
{{- $extAuthServerPort := $.Values.global.glooMtls.enabled | ternary 8084 $extAuth.deployment.port -}}
{{- $extAuthMode := default "sidecar" .ExtAuthMode -}}
- image: {{template "gloo.image" $image}}
  {{- if $extAuth.deployment.resources }}
  resources:
{{ toYaml $extAuth.deployment.resources | indent 4}}
  {{- end}}
  imagePullPolicy: {{ $image.pullPolicy }}
  name: {{ $extAuth.deployment.name }}
  env:
{{- if $extAuth.deployment.customEnv }}
{{ toYaml $extAuth.deployment.customEnv | indent 4 }}
{{- end }}
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          fieldPath: metadata.namespace
    - name: SERVICE_NAME
      value: {{ $extAuth.serviceName | quote }}
    - name: GLOO_ADDRESS
{{- if and $extAuth.deployment.glooAddress $extAuth.deployment.glooPort }}
      value: {{ $extAuth.deployment.glooAddress }}:{{ $extAuth.deployment.glooPort }}
{{- else }}
      {{- if $.Values.global.glooMtls.enabled }}
      value: "127.0.0.1:9955"
      {{- else }}
      {{- if $.Values.gloo.gloo }}
      value: gloo:{{ .Values.gloo.gloo.deployment.xdsPort }}
      {{- else }}
      value: gloo:{{ $.Values.gloo.deployment.xdsPort }}
      {{- end }}
      {{- end }}
{{- end }}
    - name: SIGNING_KEY
      valueFrom:
        secretKeyRef:
          name: {{ $extAuth.signingKey.name }}
          key: signing-key
    {{- if $.Values.global.extensions.glooRedis.enableAcl }}
    - name: REDIS_PASSWORD
      valueFrom:
        secretKeyRef:
          name: redis
          key: redis-password
    {{- end }}
    {{- if $extAuth.deployment.debugPort }}
    - name: DEBUG_PORT
      value: {{ $extAuth.deployment.debugPort | quote }}
    {{- end }}
    - name: SERVER_PORT
      value: {{ $extAuthServerPort | quote }}
    {{- if eq $extAuthMode "sidecar" }}
    - name: UDS_ADDR
      value: "/usr/share/shared-data/.sock"
    {{- end }}
    {{- if $extAuth.userIdHeader }}
    - name: USER_ID_HEADER
      value: {{ $extAuth.userIdHeader  | quote }}
    {{- end }}
    {{- if $statsConfig.enabled }}
    - name: START_STATS_SERVER
      value: "true"
    {{- end}}
    {{- if $extAuth.tlsEnabled }}
    - name: TLS_ENABLED
      value: "true"
    {{- end}}
    {{- if $extAuth.secretName }}
    - name: CERT
      valueFrom:
        secretKeyRef:
          name: {{ $extAuth.secretName }}
          key: tls.crt
    - name: KEY
      valueFrom:
        secretKeyRef:
          name: {{ $extAuth.secretName }}
          key: tls.key
    {{- end}}
    {{- if $extAuth.certPath }}
    - name: CERT_PATH
      value: {{ $extAuth.certPath }}
    {{- end}}
    {{- if $extAuth.keyPath }}
    - name: KEY_PATH
      value: {{ $extAuth.keyPath }}
    {{- end}}
    - name: HEALTH_HTTP_PORT
      value: "8082"
    - name: HEALTH_HTTP_PATH
      value: "/healthcheck"
    - name: ALIVE_HTTP_PATH
      value: "/alivecheck"
    {{- if $extAuth.headersToRedact }}
    - name: HEADERS_TO_REDACT
      value: {{ $extAuth.headersToRedact | quote }}
    {{- end }}
    {{- if $extAuth.deployment.logLevel }}
    - name: LOG_LEVEL
      value: {{ $extAuth.deployment.logLevel | quote }}
    {{- end }}
  readinessProbe:
    httpGet:
      port: 8082
      path: "/healthcheck"
    initialDelaySeconds: 2
    periodSeconds: 5
    failureThreshold: 2
    successThreshold: 1
  {{- if $extAuth.deployment.livenessProbeEnabled }}
  livenessProbe:
    httpGet:
      port: 8082
      path: "/alivecheck"
    initialDelaySeconds: 3
    periodSeconds: 10
    failureThreshold: 3
    successThreshold: 1
  {{- end }}
  {{- if $statsConfig.podMonitorEnabled }}
  ports:
    - name: http-monitoring
      containerPort: 9091
  {{- end }}
{{- if or $extAuth.deployment.extraVolumeMount (or $extAuth.plugins (or (eq $extAuthMode "sidecar") (($extAuth.deployment.redis).certs))) }}
  volumeMounts:
  {{- if $extAuth.deployment.extraVolumeMount }}
   {{- toYaml $extAuth.deployment.extraVolumeMount | nindent 2 }}
  {{- end }}
  {{- if eq $extAuthMode "sidecar" }}
  - name: shared-data
    mountPath: /usr/share/shared-data
  {{- end }}
  {{- if $extAuth.plugins }}
  - name: auth-plugins
    mountPath: /auth-plugins
  {{- end }}
  {{- if (($extAuth.deployment.redis).certs) }}
  {{- range $extAuth.deployment.redis.certs }}
  - mountPath: {{ .mountPath }}
    name: user-session-cert-{{ .secretName }}
  {{- end }}{{/* range $extAuth.deployment.redis.certs */}}
  {{- end }}{{/* $extAuth.deployment.redis */}}   
  {{- end }}{{/* if or volumeMounts */}}
{{- end }}{{/* define "gloo.extauthcontainer" */}}

{{/* Helper used to properly set the ProxiesToCreateDataplaneFor value at the top scope.
     This exists because we need to iterate over the provided proxies if the `dataplanePerProxy`
     helm value is true, but we don't want to iterate over the proxies if this value is false.

     Since there are no conditional ranges in helm, instead opted to create the map with the
     correct contents (i.e., if `dataplanePerProxy` is false, just pick any proxy to do the render).

     Pulled this logic out into a helm helper so we don't have to duplicate it everywhere it's needed
 */}}
{{- define "gloo.dataplaneperproxyhelper" -}}
{{- $proxiesToCreateDataplaneFor := dict }}
{{- if $.Values.global.extensions.dataplanePerProxy }}
{{ $proxiesToCreateDataplaneFor = merge $proxiesToCreateDataplaneFor .Values.gloo.gatewayProxies }}
{{- else }}
{{/*
Find the first gateway proxy that isn't disabled
*/}}
{{- $nonDisabledGwProxies := dict }}
{{- range $gwProxyName, $gwProxy := .Values.gloo.gatewayProxies -}}
{{- if not $gwProxy.disabled }}
{{- $nonDisabledGwProxies := set $nonDisabledGwProxies $gwProxyName $gwProxy}}
{{- end }}
{{- end }}
{{- $firstKey := keys $nonDisabledGwProxies | sortAlpha | first }}
{{- $proxiesToCreateDataplaneFor = pick $nonDisabledGwProxies $firstKey }}
{{- end }}
{{- $_ := set $ "ProxiesToCreateDataplaneFor" $proxiesToCreateDataplaneFor -}}
{{- end }}

{{/*
Expand the name of a container image
*/}}
{{- define "glooe.imagenonextended" -}}
{{ .registry }}/{{ .repository }}:{{ .tag }}
{{- end -}}

{{/*
Injection point for enterprise-exclusive settings into the settings manifest
*/}}
{{- define "gloo.extraSpecs" -}}
{{- if not $.Values.global.extauthCustomYaml }}
{{- $extauth := $.Values.global.extensions.extAuth }}
{{- if $extauth.enabled }}
  {{- if or $extauth.envoySidecar $extauth.standaloneDeployment }}
  extauth:
    transportApiVersion: {{ $extauth.transportApiVersion | default "V3" }}
    extauthzServerRef:
      # arbitrarily default to the standalone deployment name even if we're using both
      {{- if $extauth.standaloneDeployment }}
      name: extauth
      {{- else }}
      name: extauth-sidecar
      {{- end }}
      namespace: {{ .Release.Namespace }}
    {{- if $extauth.requestTimeout }}
    requestTimeout: {{ quote $extauth.requestTimeout }}
    {{- end }}
    {{- if $extauth.requestBody }}
    requestBody:
    {{- toYaml $extauth.requestBody | nindent 6 }}
    {{- end }}
    {{- if $extauth.userIdHeader }}
    userIdHeader: {{ quote $extauth.userIdHeader }}
    {{- end }}
  {{- end }}
{{- end}}
{{- end}}
{{- if $.Values.global.extensions.rateLimit.enabled }}
  ratelimitServer:
    rateLimitBeforeAuth: {{ .Values.global.extensions.rateLimit.beforeAuth | default "false" }}
    ratelimitServerRef:
      name: rate-limit
      namespace: {{ .Release.Namespace }}
{{- end }} {{/* if $.Values.global.extensions.rateLimit.enabled */}}
{{- if $.Values.global.extensions.caching.enabled }}
  cachingServer:
    cachingServiceRef:
      name: caching-service
      namespace: {{ .Release.Namespace }}
{{- end }} {{/* if $.Values.global.extensions.caching.enabled */}}
{{- $consoleOpts := $.Values.global.console | default dict }}
  consoleOptions:
    readOnly: {{ hasKey $consoleOpts "readOnly" | ternary $consoleOpts.readOnly false }}
    apiExplorerEnabled: {{ hasKey $consoleOpts "apiExplorerEnabled" | ternary $consoleOpts.apiExplorerEnabled true }}
{{- if (($.Values.global.graphql).changeValidation) }}
{{- $changeValidation := $.Values.global.graphql.changeValidation }}
  graphqlOptions:
    schemaChangeValidationOptions:
      rejectBreakingChanges: {{ ternary true false $changeValidation.rejectBreaking }}
      {{- $rules := $changeValidation.rules | default dict }}
      {{- if or $rules.dangerousToBreaking $rules.deprecatedFieldRemovalDangerous $rules.ignoreDescriptionChanges $rules.ignoreUnreachable }}
      processingRules:
      {{- if $rules.dangerousToBreaking }}
        - RULE_DANGEROUS_TO_BREAKING
      {{- end }}
      {{- if $rules.deprecatedFieldRemovalDangerous }}
        - RULE_DEPRECATED_FIELD_REMOVAL_DANGEROUS
      {{- end }}
      {{- if $rules.ignoreDescriptionChanges }}
        - RULE_IGNORE_DESCRIPTION_CHANGES
      {{- end }}
      {{- if $rules.ignoreUnreachable }}
        - RULE_IGNORE_UNREACHABLE
      {{- end }}
      {{- else }}
      processingRules: []
      {{- end }} {{/* if or $rules.dangerousToBreaking $rules.deprecatedFieldRemovalDangerous $rules.ignoreDescriptionChanges $rules.ignoreUnreachable */}}
{{- end }} {{/* if (($.Values.global.graphql).changeValidation) */}}
{{- end -}} {{/* define "gloo.extraSpecs" */}}
