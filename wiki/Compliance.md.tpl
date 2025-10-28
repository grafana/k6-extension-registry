Compliance check results for all registered extensions.

### Checkers

Compliance with the requirements expected of k6 extensions is checked by various checkers.

  - `module` - checks if there is a valid `go.mod`
  - `replace` - checks if there is no `replace` directive in `go.mod`
  - `readme` - checks if there is a readme file
  - `examples` - checks if there are files in the `examples` directory
  - `license` - checks whether there is a suitable OSS license
  - `git` - checks if the directory is git workdir
  - `versions` - checks for semantic versioning git tags
  - `build` - checks if the latest k6 version can be built with the extension
  - `smoke` - checks if the smoke test script exists and runs successfully (`smoke.js`, `smoke.ts`, `smoke.test.js` or `smoke.test.ts` in the `test`,`tests`, `examples` or the base directory)
  - `types` - checks if the TypeScript API declaration file exists (`index.d.ts` in the `docs`, `api-docs` or the base directory)
  - `codeowners` - checks if there is a CODEOWNERS file (for official extensions) (in the `.github` or `docs` or in the base directory)


Repository | Description | Version | Issues
-----------|-------------|---------|--------
{{- range $idx, $ext:= .registry -}}
{{ if (ne $ext.module "go.k6.io/k6") -}}
{{- if coll.Has $ext "compliance" -}}
{{-   $versions := coll.Keys $ext.compliance | coll.Sort -}}
{{-   range $vidx, $version := $versions -}}
{{-     $comp := index $ext.compliance $version -}}
{{-     if eq $vidx 0 }}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }} | {{ $version }} | {{if coll.Has $comp "issues"}}{{ range $i, $issue := $comp.issues }}{{$issue}} {{end}} {{else}} 🎉 {{end }}
{{-     else }}
&nbsp; | &nbsp; | {{ $version }} | {{if coll.Has $comp "issues"}}{{ range $i, $issue := $comp.issues }}{{$issue}} {{end}} {{else}} 🎉 {{end }}
{{-     end -}}
{{-   end -}}
{{- else -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }} | - | 🎉
{{- end -}}
{{ end -}}
{{ end }}

The **issues** column contains the IDs of the failed checkers.