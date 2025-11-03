Set of k6 extensions that are officially supported by Grafana.

Name | Description | Availability
-----|-------------|-------------
{{ range $idx, $ext:= coll.Sort "module" .registry -}}
{{ if and (eq $ext.tier "official") (ne $ext.module "go.k6.io/k6") -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }}
{{ end -}}
{{ end }}

The list can be downloaded in [JSON format]({{.Env.BASE_URL}}/tier/official.json) using the command below.

```bash
curl {{.Env.BASE_URL}}/tier/official.json
```