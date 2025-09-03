{
{{- $first := true -}}
{{- range $extension := .registry -}}
  {{- template "processExtensionEntries" (dict "extension" $extension "isFirst" $first) -}}
  {{- if or (and (has $extension "imports") $extension.imports) (and (has $extension "outputs") $extension.outputs) -}}
    {{- $first = false -}}
  {{- end -}}
{{- end -}}
}
