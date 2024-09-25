# k6 Extension Registry

The source of the **k6 Extension Registry** https://registry.k6.io

## Registration

Check the [Contributing Guidelines](CONTRIBUTING.md) for the extension registration process.

## Custom registry

A custom registry can be created and maintained using the [k6registry](https://github.com/grafana/k6registry) tool. The content of the registry and the catalog can be fully controlled by the user.

## Registered Properties

Only those properties of the extensions are registered, which either cannot be detected automatically, or delegation to the extension is not allowed.

Properties that are available using the repository manager API (GitHub API, GitLab API, etc) are intentionally not registered. For example, the number of stars can be queried via the repository manager API, so this property is not registered.

Exceptions are the string-like properties that are embedded in the Grafana documentation. These properties are registered because it is not allowed to inject arbitrary text into the Grafana documentation site without approval. Therefore, these properties are registered (eg `description`)

The properties provided by the repository managers are queried during registry processing and can be used to produce the output properties.

**example entry**

```yaml
- module: github.com/grafana/xk6-sql
  description: Load test SQL Servers
  imports:
    - k6/x/sql
  tier: official
  products: ["cloud", "oss"]
  categories:
    - data
```

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

Extensions owned by the `grafana` GitHub organization are not officially supported by Grafana by default.

### `products`

Products in which the extension can be used. **Optional, defaults to `["oss"]`**

### `categories`

The categories to which the extension belongs. **Optional, defaults to `["misc"]`**

### `versions`

List of supported versions. **Optional, the default is to query the repository manager API**

Normally, the registration does not include this property, it is automatically queried using the repository manager API. Automation can be disabled by setting it and only the versions specified here will be available.

### `constraints`

Version constraints. **Optional, the default is to use all detected versions**

Version constraints are primarily used to filter automatically detected versions. It can also be used to filter the versions property imported from the origin registry.

## Schema

The [schema documentation](https://registry.k6.io/registry.schema.html) contains a detailed description of the properties available in the registry.

Check the [Contributing Guidelines](CONTRIBUTING.md) for contributing to the registry schema.
