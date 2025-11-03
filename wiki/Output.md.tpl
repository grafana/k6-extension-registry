Set of k6 extensions to process the metrics emitted by k6 or publish them to unsupported backend stores.

Name | Description
-----|------------
{{ range $idx, $ext:= coll.Sort "module" .registry -}}
{{ if and (has $ext "outputs") ($ext.outputs) (ne $ext.module "go.k6.io/k6") -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }}
{{ end -}}
{{ end }}
