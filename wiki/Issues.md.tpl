Lists of extensions based on issues found by the compliance check. A specific extension can be included in several lists, since an extension can have several issues.

{{- $k6_version := "" -}}
{{- range $idx, $ext:= .registry -}}
{{-   if (eq $ext.module "go.k6.io/k6") -}}
{{-     $k6_version = (index $ext.versions 0) -}}
{{-     break -}}
{{-   end -}}
{{- end -}}
{{- $summaries := dict
        "build" (print "The following extensions are not buildable with the latest ([" $k6_version "](https://github.com/grafana/k6/releases/tag/" $k6_version ")) k6 version.")
        "codeowners" "The following official extensions do not have a `CODEOWNERS` file."
        "types" "The following JavaScript extensions do not have a TypeScript API declaration (`index.d.ts`)."
        "examples" "The following JavaScript extensions do not have examples in the `examples` folder."
        "replace" "There is a replace directive in the `go.mod` file of the extensions below."
        "smoke" "The following JavaScript extensions do not have a smoke test script (`smoke.js`, `smoke.test.js`, `smoke.ts`, `smoke.test.ts` file in the `test`, `tests`, `examples` or base directory)."
        "module" "The extensions below do not have a valid `go.mod` file."
        "readme" "The extensions below do not have a readme file."
        "license" "The extensions below do not have a suitable open-source license file."
        "git" "The extensions below do not have a git repository (this is not possible, it can only happen locally)."
        "versions" "The extensions below do not have semantic version tags."
        "security" "The following extensions have security issues."
        "vulnerability" "The following extensions have known vulnerabilities."
 -}}
{{- $issue_types := coll.Slice "module" "replace" "readme" "examples" "license" "git" "versions" "build" "smoke" "types" "codeowners" "security" "vulnerability" -}}
{{- range $issue_type := $issue_types -}}
{{-   $has_extensions := false -}}
{{-   range $idx, $ext := $.registry -}}
{{-     if and (coll.Has $ext "compliance") (coll.Has $ext.compliance "issues") (coll.Has $ext.compliance.issues $issue_type) -}}
{{-       $has_extensions = true -}}
{{-       break -}}
{{-     end -}}
{{-   end -}}
{{-   if $has_extensions }}

## {{$issue_type}}
{{ default "" (index $summaries $issue_type) }}

Repository | Description
-----------|------------
{{-     range $idx, $ext := $.registry }}
{{-       if and (coll.Has $ext "compliance") (coll.Has $ext.compliance "issues") (coll.Has $ext.compliance.issues $issue_type) }}
{{          if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }}
{{-       end }}
{{-     end }}

{{-   end }}
{{- end }}
