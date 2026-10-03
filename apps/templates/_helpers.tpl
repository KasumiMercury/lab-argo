{{/* Sync policy shared by every Application */}}
{{- define "apps.syncPolicy" -}}
automated:
  prune: true
  selfHeal: true
retry:
  limit: 5
  backoff:
    duration: 10s
    factor: 2
    maxDuration: 3m
syncOptions:
  - CreateNamespace=true
{{- range .syncOptions }}
  - {{ . }}
{{- end }}
{{- end }}
