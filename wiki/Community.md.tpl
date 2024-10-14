Set of k6 extensions developed by the community, without official support.

Name | Description
-----|------------
{{ range $idx, $ext:= .registry -}}
{{ if and (eq $ext.tier "community") (ne $ext.module "go.k6.io/k6") -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }}
{{ end -}}
{{ end }}

The list can be downloaded in [JSON format]({{.Env.BASE_URL}}/tier/community.json) using the command below.

```bash
curl {{.Env.BASE_URL}}/tier/community.json
```