Objective and Key Results for **official k6 extensions** based on the contents of the k6 extension registry.
{{ $props := index .schema "$defs" "metrics" "properties" }}

## Objective

Official extensions must pass all compliance checks.

## Key Results

{{- $extension_count := index .official_metrics "extension_count" -}}
{{- $no_issues_count := 0 -}}
{{- $issues := coll.Slice -}}
{{- range $idx, $ext:= .registry -}}
{{- if and (eq $ext.tier "official") (ne $ext.module "go.k6.io/k6") ($ext.compliance) (not (index $ext.compliance "issues")) -}}
{{- $no_issues_count = add $no_issues_count 1 -}}
{{- else -}}
{{-  if and (eq $ext.tier "official") (has $ext "compliance") -}}
{{-  range $i, $issue := (index $ext.compliance "issues") -}}
{{-   $issues = $issues | coll.Append $issue | uniq -}}
{{-  end -}}
{{-  end -}}
{{- end -}}
{{- end -}}
{{- $no_issues_pc := math.Round (mul (div $no_issues_count $extension_count) 100) }}

### Pass all checks: {{ $no_issues_count }} / {{ $extension_count }} ({{ $no_issues_pc }}%)

{{ if ne $no_issues_pc 100.0 }}

The following extensions have compliance issues.

Name | Issues | Description
-----|--------|------------
{{ range $idx, $ext:= .registry -}}
{{ if and (eq $ext.tier "official") (ne $ext.module "go.k6.io/k6") -}}
{{ if coll.Has $ext.compliance "issues" -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ range $idx, $issue := $ext.compliance.issues }}{{$issue}} {{end}} | {{ $ext.description }}
{{ end -}}
{{ end -}}
{{ end }}

**Explanation of compliance checks:**

{{- range $i, $issue := $issues -}}
{{- if eq "module" $issue }}
  - `module` - checks if there is a valid `go.mod`
{{- else if eq "replace" $issue }}
  - `replace` - checks if there is no `replace` directive in `go.mod`
{{- else if eq "readme" $issue }}
  - `readme` - checks if there is a readme file
{{- else if eq "examples" $issue }}
  - `examples` - checks if there are files in the `examples` directory
{{- else if eq "license" $issue }}
  - `license` - checks whether there is a suitable OSS license
{{- else if eq "git" $issue }}
  - `git` - checks if the directory is git workdir
{{- else if eq "versions" $issue }}
  - `versions` - checks for semantic versioning git tags
{{- else if eq "build" $issue }}
  - `build` - checks if the latest k6 version can be built with the extension
{{- else if eq "smoke" $issue }}
  - `smoke` - checks if the smoke test script exists and runs successfully (`smoke.js`, `smoke.ts`, `smoke.test.js` or `smoke.test.ts` in the `test`,`tests`, `examples` or the base directory)
{{- else if eq "types" $issue }}
  - `types` - checks if the TypeScript API declaration file exists (`index.d.ts` in the `docs`, `api-docs` or the base directory)
{{- else if eq "codeowners" $issue }}
  - `codeowners` - checks if there is a CODEOWNERS file (for official extensions) (in the `.github` or `docs` or in the base directory)
{{- end }}
{{- end }}

{{ end }}