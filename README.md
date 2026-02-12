# k6 Extension Registry

The k6 extensions registry maintains the list of k6 extensions supported by k6.

Extensions in this registry are [natively supported by k6](https://grafana.com/docs/k6/latest/extensions/run/#using-automatic-extension-loading).

Extensions not listed in the registry can be used by [building custom k6 binaries using xk6](https://grafana.com/docs/k6/latest/extensions/run/build-k6-binary-using-go/).

The extensions registry contains the following attributes:
 * Description of extension (name, source registry, type, tier, et cetera). These are entered when [registering the extension](#registering-an-extension) and maintained in this repository
 * Dynamic attributes retrieved from the source repository (e.g. GitHub, GitLab). For example, the number of Github stars. These attributes are automatically updated periodically.
 * Dynamic attributes resulting from the extension linting (issues found). These attributes are automatically updated periodically.

The registry is published at https://registry.k6.io.

It can be accessed using the API described in [openapi.yaml]. This API allows accessing subset of the registry by different criteria (e.g. by tier), and also fetch statistics about the extensions.

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

## Updating registry on extension releases

> [!NOTE]
> This functionality is only available for extensions in the grafana organization. Extensions in other organizations have to update the registry opening a PR.

Use the [register-version](./.github/workflows/register-version.yml) reusable workflow to automatically update registry when a new extension version is released.

This workflow requires the `k6-extension-registry-updater` github app to be installed in the extension's repository, and the apps credentials (app id and private key) to be passed as secrets when calling the workflow. This credential can be obtained following the stablish procedures in grafana.

**Example:**

```yaml
name: Release

on:
  push:
    tags: ["v*.*.*"]

jobs:
  release:
    name: Release
    uses: grafana/xk6/.github/workflows/extension-release.yml@v1.1.4
    permissions:
      contents: write
    with:
      go-version: "1.24.x"
      os: '["linux"]'
      arch: '["amd64"]'
      k6-version: "v1.2.3"
      xk6-version: "1.1.4"

  register-version:
    name: Register Version
    needs: [release]
    permissions:
      contents: write
      pull-requests: write
    uses: grafana/k6-extension-registry/.github/workflows/register-version.yml@main
    with:
      module: github.com/grafana/xk6-example
      version: ${{ github.ref_name }}
      auto_merge: true
    # this secrets must be obtained from the secrets vault
    secrets:
      app_id: ${{ K6_EXTENSION_REGISTRY_UPDATER_ID }}
      app_pem: ${{ K6_EXTENSION_REGISTRY_UPDATER_PEM }}
```

### Workflow Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `module` | The module name to update (e.g., `github.com/grafana/xk6-sql`) | Yes | - |
| `version` | The version to add (e.g., `v1.0.6`) | Yes | - |
| `auto_merge` | Enable auto-merge for trusted sources | No | `true` |

### Workflow Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `app_id` | GitHub App ID for registry updater | Yes |
| `app_pem` | GitHub App private key (PEM) for registry updater | Yes |

### Features

- **Pull request creation**: Creates a pull request with detailed information about the update
- **Auto-merge**: Trusted sources can have their updates automatically merged
- **Security**: Cross-validates repository URLs and module paths to prevent malicious updates
