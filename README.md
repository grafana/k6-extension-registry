# k6 Extension Registry

The k6 extension registry source is a YAML file ([registry.yaml](registry.yaml)) that contains the most important properties of extensions. An automatic workflow completes the source of the registry with properties that can be queried on the repository manager APIs (versions, stars, etc.) and keeps it up-to-date in a JSON file ([registry.json](https://grafana.github.io/k6-extension-registry/registry.json)).

An up-to-date version of the k6 extension registry is available at https://grafana.github.io/k6-extension-registry/registry.json

In addition to the extension registry, the following k6 extension catalogs are automatically kept up-to-date:

- [catalog-registered.json](https://grafana.github.io/k6-extension-registry/catalog-registered.json) contains all registered extensions
- [catalog-official.json](https://grafana.github.io/k6-extension-registry/catalog-official.json) contains officially supported extensions (`official` flag is true)
- [catalog-cloud.json](https://grafana.github.io/k6-extension-registry/catalog-cloud.json) contains extensions available in the cloud (`cloud` flag is true)


The [extensions.json](https://grafana.github.io/k6-extension-registry/extensions.json) is also kept up-to-date for documentation purposes. This is a simplified version of [registry.json](https://grafana.github.io/k6-extension-registry/registry.json) with a structure similar to the [legacy extensions.json](https://github.com/grafana/k6-docs/blob/main/src/data/doc-extensions/extensions.json).

## Contributing

To contribute, you need to modify the `registry.yaml` file and then open a pull request. The [Update](https://github.com/grafana/k6-extension-registry/actions/workflows/update.yml) workflow will automatically validate the `registry.yaml` file and, after successful validation, generate the `registry.json` file.

After the pull request is merged, the new extension registry (and extension catalogs) will be automatically deployed to GitHub Pages.

## Registry Validation

The registry is validated using [JSON schema](https://grafana.github.io/k6registry/registry.schema.json). Requirements that cannot be validated using the JSON schema are validated using [custom linter](https://github.com/grafana/k6registry).

Custom linter checks the following for each extension:

  - Is the go module path valid?
  - Is there at least one versioned release?
  - Is a valid license configured?
  - Is the xk6 topic set for the repository?
  - Is the repository not archived?


## Registry Source

The k6 extension registry source is a YAML file that contains the most important properties of extensions.

### File format

The k6 extension registry source format is YAML, because the registry is edited by humans and the YAML format is more human-friendly than JSON. The files generated from the registry are typically in JSON format, because they are processed by programs and JSON is more widely supported than YAML. A JSON format is also generated from the entire registry, so that it can also be processed by programs.

### Registered Properties

Only those properties of the extensions are registered, which either cannot be detected automatically, or delegation to the extension is not allowed.

Properties that are available using the repository manager API (GitHub API, GitLab API, etc) are intentionally not registered. For example, the number of stars can be queried via the repository manager API, so this property is not registered.

Exceptions are the string-like properties that are embedded in the Grafana documentation. These properties are registered because it is not allowed to inject arbitrary text into the Grafana documentation site without approval. Therefore, these properties are registered (eg `description`)

The properties provided by the repository managers ([Repository Metadata]) are queried during registry processing and can be used to produce the output properties.

### Extension Identification

The primary identifier of an extension is the extension's [go module path].

The extension does not have a `name` property, the [repository metadata] can be used to construct a `name` property. Using the repository owner and the repository name, for example, `grafana/xk6-dashboard` can be generated for the `github.com/grafana/xk6-dashboard` extension.

The extension does not have a `url` property, but there is a `url` property in the [repository metadata].

[go module path]: https://go.dev/ref/mod#module-path
[Repository Metadata]: #repository-metadata

### JavaScript Modules

The JavaScript module names implemented by the extension can be specified in the `imports` property. An extension can register multiple JavaScript module names, so this is an array property.

### Output Names

The output names implemented by the extension can be specified in the `outputs` property. An extension can register multiple output names, so this is an array property.

### Cloud

The `true` value of the `cloud` flag indicates that the extension is also available in the Grafana k6 cloud. The use of certain extensions is not supported in a cloud environment. There may be a technological reason for this, or the extension's functionality is meaningless in the cloud.

### Official

The `true` value of the `official` flag indicates that the extension is officially supported by Grafana. Extensions owned by the `grafana` GitHub organization are not officially supported by Grafana by default. There are several k6 extensions owned by the `grafana` GitHub organization, which were created for experimental or example purposes only. The `official` flag is needed so that officially supported extensions can be distinguished from them.

### Example registry

```yaml file=example.yaml
- module: github.com/grafana/xk6-dashboard
  description: Web-based metrics dashboard for k6
  outputs:
    - dashboard
  official: true

- module: github.com/grafana/xk6-sql
  description: Load test SQL Servers
  imports:
    - k6/x/sql
  cloud: true
  official: true

- module: github.com/grafana/xk6-distruptor
  description: Inject faults to test
  imports:
    - k6/x/distruptor
  official: true

- module: github.com/szkiba/xk6-faker
  description: Generate random fake data
  imports:
    - k6/x/faker
```

### Repository Metadata

Repository metadata provided by the extension's git repository manager. Repository metadata are not registered, they are queried at processing time using the repository manager API.

#### Owner

The `owner` property contains the owner of the extension's git repository.

#### Name

The `name` property contains the name of the extension's git repository.

#### License

The `license` property contains the SPDX ID of the extension's license. For more information about SPDX, visit https://spdx.org/licenses/

#### Public

The `true` value of the `public` flag indicates that the repository is public, available to anyone.

#### URL

The `url` property contains the URL of the repository. The `url` is provided by the repository manager and can be displayed in a browser.

#### Homepage

The `homepage` property contains the project homepage URL. If no homepage is set, the value is the same as the `url` property.

#### Stars

The `stars` property contains the number of stars in the extension's repository. The extension's popularity is indicated by how many users have starred the extension's repository.

#### Topics

The `topics` property contains the repository topics. Topics make it easier to find the repository. It is recommended to set the `xk6` topic to the extensions repository.

#### Versions

The `versions` property contains the list of supported versions. Versions are tags whose format meets the requirements of semantic versioning. Version tags often start with the letter `v`, which is not part of the semantic version.

#### Archived

The `true` value of the `archived` flag indicates that the repository is archived, read only.

If a repository is archived, it usually means that the owner has no intention of maintaining it. Such extensions should be removed from the registry.
