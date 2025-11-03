Set of k6 extensions to extend the JavaScript functionality of test scripts or add support for a new protocol to test.

Name | Description
-----|------------
{{ range $idx, $ext:= coll.Sort "module" .registry -}}
{{ if and (has $ext "imports") ($ext.imports) (ne $ext.module "go.k6.io/k6") -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }}
{{ end -}}
{{ end }}
