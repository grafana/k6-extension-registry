Objective and Key Results for **official k6 extensions** based on the contents of the k6 extension registry.
{{ $props := index .schema "$defs" "metrics" "properties" }}

## Objective

Official extensions must meet all compliance requirements.

## Key Results

{{- $grade_a_count := index .official_metrics "grade_a_count" -}}
{{- $extension_count := index .official_metrics "extension_count" -}}
{{- $grade_a_pc := math.Round (mul (div $grade_a_count $extension_count) 100) -}}

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

### Grade: {{ $grade_a_pc }}%

All official extensions should have a compliance grade of A.

{{ if ne $grade_a_count $extension_count }}
Grade | Count
------|------
{{ range $key, $value:= .official_metrics }}
{{-  if and (strings.Contains "grade_" $key) (has $props $key) -}}
{{-    ($key|strings.TrimSuffix "_count"|strings.TrimPrefix "grade_" |toUpper) }} | {{ $value }}
{{ end -}}
{{ end}}
{{ end}}
### No Issues: {{ $no_issues_pc }}%

Official extensions should not have compliance issues.

{{ if ne $no_issues_pc 100.0 }}
Has Issues | No Issues
-----------|----------
{{ sub $extension_count $no_issues_count }} | {{ $no_issues_count }}
{{ end }}

{{ if ne $no_issues_pc 100.0 }}
## To-do's

The following extensions have compliance issues. The goal is to fix these issues and empty the table.

Name | Issues | Description
-----|--------|------------
{{ range $idx, $ext:= .registry -}}
{{ if and (eq $ext.tier "official") (ne $ext.module "go.k6.io/k6") ($ext.compliance) (ne $ext.compliance.grade "A") -}}
![grade {{$ext.compliance.grade}}]({{$.Env.BASE_URL}}/module/{{$ext.module}}/grade.svg) {{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{if coll.Has $ext.compliance "issues"}}{{ range $idx, $issue := $ext.compliance.issues }}{{$issue}} {{end}} {{else}} 🎉 {{end}} | {{ $ext.description }}
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