# k6 Extension Registry

The k6 extensions registry maintains the list of k6 extensions supported by k6.

Extensions in this registry are [natively supported by k6](https://grafana.com/docs/k6/latest/extensions/run/#using-automatic-extension-loading).

Extensions not listed in the registry can be used by [building custom k6 binaries using xk6](https://grafana.com/docs/k6/latest/extensions/run/build-k6-binary-using-go/).

The extensions registry contains the following attributes:
 * Description of extension (name, source registry, type, tier, et cetera). These are entered when [registering the extension](#registering-an-extension) and maintained in this repository
 * Dynamic attributes retrieved from the source repository (e.g. GitHub, GitLab). For example, the number of Github stars. These attributes are automatically updated periodically.
 * Dynamic attributes resulting from the extension linting (grade, issues found). These attributes are automatically updated periodically.

The registry is published at https://registry.k6.io.

It can be accessed using the API described in [openapi.yaml]. This API allows accessing subset of the registry by different criteria (tier, grade), and also fetch statistics about the extensions.

The [Wiki](https://github.com/grafana/k6-extension-registry/wiki) has human-readable reports based on registry content.

## Registering an extension

> [!IMPORTANT]
> Before registering a new extension, please read the [Registry Requirements](https://grafana.com/docs/k6/latest/extensions/create/extensions-registry/).

The source of the registry can be found in the [registry.yaml] file. To register an extension, simply add a new entry to the end of the file.

**example entry**

```yaml
- module: github.com/grafana/xk6-sql
  description: Load test SQL Servers
  imports:
    - k6/x/sql
  tier: official
```

### Properties

### `module`

The primary identifier of an extension is the extension's [go module path](https://go.dev/ref/mod#module-path). **Required**

### `description`

Brief description of the extension. **Required**

### `imports`

The JavaScript module names implemented by the extension.An extension can register multiple JavaScript module names, so this is an array property. **Either `imports` or `outputs` are required**

### `outputs`

The output names implemented by the extension. An extension can register multiple output names, so this is an array property. **Either `imports` or `outputs` are required**

### `tier`

Refers to the maintainer of the extension. **Optional, defaults to `community`**

> [!NOTE]
> Extensions owned by the `grafana` GitHub organization are not officially supported by Grafana by default.

### `versions`

List of supported versions. **Optional, the default is to query the repository manager API**

Normally, the registration does not include this property, it is automatically queried using the repository manager API. Automation can be disabled by setting it and only the versions specified here will be available.

### `constraints`

Version constraints. **Optional, the default is to use all detected versions**

Version constraints are primarily used to filter automatically detected versions. It can also be used to filter the versions property imported from the origin registry.

### `cgo`

Flag indicating the need for cgo. **Optional, cgo is not enabled by default**

The `cgo` property value `true` indicates that cgo must be enabled to build the extension.

## GitHub Action for Version Updates

This repository includes a reusable GitHub Action that can be used from other repositories to automatically add new versions to the registry when releases are published.

## Automatically updating the registry from a module release workflow

Use the [register-version](./actions/register-version.yml) action to automatically update the registry when publishing new versions of your extension:

```yaml
- name: Update extension registry
  uses: grafana/k6-extension-registry/actions/register-version@main
  with:
    module: ${{ github.repository }}
    version: ${{ github.event.release.tag_name }}
```

### Action Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `module` | The module name to update (e.g., `github.com/grafana/xk6-sql`) | Yes | - |
| `version` | The version to add (e.g., `v1.0.6`) | Yes | - |
| `registry-path` | Path to the registry.yaml file | No | `registry.yaml` |

The action will automatically handle checking if the module exists, whether the version is already present, and updating the registry file using `yq` for safe YAML manipulation.
