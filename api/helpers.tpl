{{- /* Helper template to process imports and outputs for an extension */ -}}
{{- define "processExtensionEntries" -}}
  {{- $extension := .extension -}}
  {{- $isFirst := .isFirst -}}
  
  {{- if (has $extension "imports") -}}
    {{- if $extension.imports -}}
      {{- range $extension.imports -}}
        {{- if not $isFirst -}},{{- end -}}
        {{- $isFirst = false -}}
        "{{ . }}": {{ toJSON $extension }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
  
  {{- if (has $extension "outputs") -}}
    {{- if $extension.outputs -}}
      {{- range $extension.outputs -}}
        {{- if not $isFirst -}},{{- end -}}
        {{- $isFirst = false -}}
        "{{ . }}": {{ toJSON $extension }}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
