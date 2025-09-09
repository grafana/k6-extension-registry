**Welcome to the k6 Extension Registry wiki!**

*Various reports on the availability of [Grafana k6 extensions](https://grafana.com/docs/k6/latest/extensions/) can be found here.*

The content of the wiki is generated automatically, so it is consistent with the state of the [current registry](https://registry.k6.io/registry.json). Use the sidebar on the right to navigate between the reports. The [k6 Extension Registry Service UI]({{.Env.BASE_URL}}/ui/) can be used for interactive API queries.

The following table lists all registered k6 extensions.

Repository | Description | Tier
-----------|-------------|-------------
{{ range $idx, $ext:= .registry -}}
{{ if (ne $ext.module "go.k6.io/k6") -}}
{{ if and $ext.repo $ext.repo.url }}[{{ $ext.repo.owner }}/{{ $ext.repo.name }}]({{$ext.repo.url}}){{else}}{{ $ext.module }}{{end}} | {{ $ext.description }} | {{ $ext.tier }}
{{ end -}}
{{ end }}

The list can be downloaded in [JSON format]({{.Env.BASE_URL}}/registry.json) using the command below.

```bash
curl '{{.Env.BASE_URL}}/registry.json'
```

> [!WARNING]
> Do not modify the wiki manually!
> The entire wiki is generated automatically, so changes will be overwritten!