Objective and Key Results for **official k6 extensions** based on the contents of the k6 extension registry.
{{ $props := index .schema "$defs" "metrics" "properties" }}

## Objective

Official extensions must pass all compliance checks.

## Key Results

{{- $extension_count := index .official_metrics "extension_count" -}}
{{- $no_issues_count := 0 -}}
{{- $all_issues := coll.Slice -}}
{{- range $idx, $ext:= .registry -}}
{{-   if and (eq $ext.tier "official") (ne $ext.module "go.k6.io/k6") -}}
{{-     $has_any_issues := false -}}
{{-     if coll.Has $ext "compliance" -}}
{{-       range $version, $comp := $ext.compliance -}}
{{-         if coll.Has $comp "issues" -}}
{{-           $has_any_issues = true -}}
{{-           range $i, $issue := $comp.issues -}}
{{-             $all_issues = $all_issues | coll.Append $issue -}}
{{-           end -}}
{{-         end -}}
{{-       end -}}
{{-     end -}}
{{-     if not $has_any_issues -}}
{{-       $no_issues_count = add $no_issues_count 1 -}}
{{-     end -}}
{{-   end -}}
{{- end -}}
{{- $issues := $all_issues | uniq -}}
{{- $no_issues_pc := math.Round (mul (div $no_issues_count $extension_count) 100) }}

### Pass all checks: {{ $no_issues_count }} / {{ $extension_count }} ({{ $no_issues_pc }}%)

{{ if ne $no_issues_pc 100.0 }}

The following extensions have compliance issues.

Name | Description | Issues
-----|-------------|--------
{{- range $idx, $ext:= .registry -}}
{{ if and (eq $ext.tier "official") (ne $ext.module "go.k6.io/k6") -}}
{{- if coll.Has $ext "compliance" -}}
{{-   $all_issues := coll.Slice -}}
{{-   range $version, $comp := $ext.compliance -}}
{{-     if coll.Has $comp "issues" -}}
{{-       range $i, $issue := $comp.issues -}}
{{-         $all_issues = $all_issues | coll.Append $issue -}}
{{-       end -}}
{{-     end -}}
{{-   end -}}
{{-   $all_issues = $all_issues | uniq -}}
{{-   if $all_issues }}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }} | {{ range $i, $issue := $all_issues }}{{$issue}} {{end }}
{{-   end -}}
{{- end -}}
{{ end -}}
{{ end }}

**Explanation of compliance checks:**

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

{{ end }}