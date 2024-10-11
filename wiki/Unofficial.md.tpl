The table below lists k6 extensions owned by Grafana Labs but not officially supported.

Name | Description
-----|------------
{{ range $idx, $ext:= .registry -}}
{{ if and (ne $ext.tier "official") (eq $ext.repo.owner "grafana") (ne $ext.module "go.k6.io/k6") -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }}
{{ end -}}
{{ end }}