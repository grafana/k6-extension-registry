Metrics made from the content of the k6 extension registry are listed here, broken down according to different aspects. The page is automatically updated when the registry changes.
{{ $props := index .schema "$defs" "metrics" "properties" }}
## Extensions by Grade

Metrics by extension compliance grades. The grade for the fully compliant (without issue) extension is A.

```mermaid
pie showData 
{{ range $key, $value:= .metrics }}
  {{- if and (strings.Contains "grade_" $key) (has $props $key) -}}
  {{- $name := strings.TrimSuffix "_count" (strings.TrimPrefix "grade_" $key) -}}
  {{- if index $.metrics $key}}"{{strings.ToUpper $name}}" : {{index $.metrics $key}}{{"\n"}}{{end}}
  {{- end -}}
{{- end -}}
```

<div align="center">

Metric | Description | Value
-------|-------|------------
{{ range $key, $value:= .metrics }}
{{-  if and (strings.Contains "_grade_" $key) (has $props $key) -}}
{{-    $key }} | {{ strings.TrimSuffix "." (index $props $key "description") }} | {{ $value }}
{{ end -}}
{{ end}}

</div>

## Extensions by Issue

Metrics by extension compliance issues. Since an extension may have several compliance issues, the sum of the values may be greater than the total number of extensions.

```mermaid
pie showData title 
{{ range $key, $value:= .metrics }}
  {{- if and (strings.Contains "issue_" $key) (has $props $key) -}}
  {{- $name := strings.TrimSuffix "_count" (strings.TrimPrefix "issue_" $key) -}}
  {{- if index $.metrics $key}}"{{$name}}" : {{index $.metrics $key}}{{"\n"}}{{end}}
  {{- end -}}
{{- end -}}
```

<div align="center">

Metric | Description | Value
-------|-------|------------
{{ range $key, $value:= .metrics }}
{{-  if and (strings.Contains "issue_" $key) (has $props $key) -}}
{{-    $key }} | {{ strings.TrimSuffix "." (index $props $key "description") }} | {{ $value }}
{{ end -}}
{{ end}}

</div>

## Extensions by Tier

```mermaid
pie showData
{{ range $key, $value:= .metrics }}
  {{- if and (strings.Contains "tier_" $key) (has $props $key) -}}
  {{- $name := strings.TrimSuffix "_count" (strings.TrimPrefix "tier_" $key) -}}
  {{- if index $.metrics $key}}"{{$name}}" : {{index $.metrics $key}}{{"\n"}}{{end}}
  {{- end -}}
{{- end -}}
```

<div align="center">

Metric | Description | Value
-------|-------|------------
{{ range $key, $value:= .metrics }}
{{-  if and (strings.Contains "tier_" $key) (has $props $key) -}}
{{-    $key }} | {{ strings.TrimSuffix "." (index $props $key "description") }} | {{ $value }}
{{ end -}}
{{ end}}

</div>

## Extensions by Type

Metrics by extension type. Since an extension can implement both JavaScript and Output extensions, the sum of the values can be greater than the total number of extensions.

```mermaid
pie showData
{{ range $key, $value:= .metrics }}
  {{- if and (strings.Contains "type_" $key) (has $props $key) -}}
  {{- $name := strings.TrimSuffix "_count" (strings.TrimPrefix "type_" $key) -}}
  {{- if index $.metrics $key}}"{{strings.ToUpper $name}}" : {{index $.metrics $key}}{{"\n"}}{{end}}
  {{- end -}}
{{- end -}}
```

<div align="center">

Metric | Description | Value
-------|-------|------------
{{ range $key, $value:= .metrics }}
{{-  if and (strings.Contains "type_" $key) (has $props $key) -}}
{{-    $key }} | {{ strings.TrimSuffix "." (index $props $key "description") }} | {{ $value }}
{{ end -}}
{{ end}}

</div>

## All metrics

The table below contains all available metrics from the registry.

<div align="center">

Metric | Description | Value
-------|-------|------------
{{ range $key, $value:= .metrics -}}
{{- if has $props $key -}}
{{ $key }} | {{ strings.TrimSuffix "." (index $props $key "description") }} | {{ $value }} 
{{ end -}}
{{ end}}

</div>

Metrics can be downloaded in [JSON format]({{.Env.BASE_URL}}/metrics.json) using the command below.

```bash
curl '{{.Env.BASE_URL}}/metrics.json'
```
