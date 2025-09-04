# Contributing Guidelines

Thank you for your interest in contributing to **k6 Extension Registry**!

To contribute, simply open a pull request.

Before you begin, make sure to familiarize yourself with the [Code of Conduct](CODE_OF_CONDUCT.md). If you've previously contributed to other open source project, you may recognize it as the classic [Contributor Covenant](https://contributor-covenant.org/).

## Contributing to the registry

> [!IMPORTANT]
> Before registering a new extension, please read the [Registry Requirements](https://grafana.com/docs/k6/latest/extensions/explanations/extensions-registry/#registry-requirements).

The source of the registry can be found in the [registry.yaml] file. To register an extension, simply add a new entry to the end of the file. The data of the already registered extension can be modified accordingly.

After modifying the [registry.yaml], it is advisable to [run the linter](#lint---run-the-linter).

The schema for the registry [registry.schema.json] file.

> [!IMPORTANT]
> The schema is maintained in [k6registry](https://github.com/grafana/k6registry) it is copied here for convenience but any change in the schema must be done in k6registry's repository. 

## Tasks

The following sections describe the typical tasks of contributing. As long as the [cdo](https://github.com/szkiba/cdo) tool is installed, these can be easily executed using it (tip: first run the `cdo` command without parameters).

### tools - Install the required tools

Contributing will require the use of some tools, which can be installed most easily with a well-configured [eget] tool.

```bash
eget grafana/k6registry
eget hairyhenderson/gomplate
pip install json-schema-for-humans
```

[eget]: https://github.com/zyedidia/eget

### lint - Run the linter

After modifying the [registry.yaml] file, it is recommended to run the static analysis using the [k6registry] command. This may take 1-2 minutes.

```bash
k6registry -q --lint registry.yaml
```

[lint]: #lint---run-the-linter
[k6registry]: https://github.com/grafana/k6registry

### public - Generate static documentation

```bash
npx @redocly/cli build-docs -o public/index.html openapi.yaml
generate-schema-doc --config with_footer=false --config collapse_long_descriptions=false registry.schema.json public/schema
mv public/schema/registry.schema.html public/schema/index.html
```

### wiki - Generate API files

The registry is exposed using and API defined in [openapi.yaml]. This API is served using static files generated from the registry using the [generate-api-files.sh] script. The script takes the registry.json generated from [registry.yaml] using `k6registry` as input to generate the json file to be returned by each endpoint. It also generates a metrics.txt file with metrics for the extensions by tier, grade, and issues found.

```bash
BUILD_DIR=build
k6registry registry.yaml > ${BUILD_DIR}/registry.json
./generate-api-files.sh -b ${BUILD_DIR}
```

### wiki - Generate wiki pages

```bash
export BASE_URL=https://registry.k6.io
curl -s -o build/registry.json $BASE_URL/registry.json
curl -s -o build/metrics.json $BASE_URL/metrics.json
curl -s -o build/official-metrics.json $BASE_URL/tier/official-metrics.json
gomplate -c registry=build/registry.json -c metrics=build/metrics.json -c official_metrics=build/tier/official-metrics.json -c schema=registry.schema.json --input-dir wiki --output-map='build/wiki/{{.in|strings.TrimSuffix ".tpl"}}'
```
