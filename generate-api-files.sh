#!/bin/bash

set -euo pipefail

# K6 Extension Registry API File Generator
#
# This script generates various files from a registry.json following the structure of the API
# described in openapi.yaml.
#
# Input: registry.json (array of extension objects) is expected in the build dir
#
# Extensions are filtered by:
# - Tier (official, community) 
# - Module: generates per-module extension metadata files


# Function to generate a file for each extension
# The module name is used as path for the file
generate_module_files() {
    $LOG "Generating module extension files..."
    
    # Return a string of the form "<module>|<module object>" for each extension
    jq -r '.[] | [.module, (. | tostring)] | join("|")' "${REGISTRY_FILE}" | \
    while IFS='|' read -r module extension_json; do
        if [[ -n "$module" ]]; then
            # Create directory for module
            local module_dir="${BUILD_DIR}/module/${module}"
            mkdir -p "${module_dir}"
            
            # Write extension.json
            echo "$extension_json" | jq . > "${module_dir}/extension.json"
        fi
    done
}

# Generate metrics for a registry
# Generates the total number of extensions and the number of extensions for each filter
# Accepted filters are 'tier' and 'issue'.
# 
# Parameters
# $1 input registry file
# $2 output metrics file in json format
# $3 output metrics file in prometheus format
# $4 timestamp for metrics
# $5 filters. Defaults to all (tier,issue)
function generate_metrics() {
    local registry=$1
    local json_file=$2
    local prometheus_file=$3
    local timestamp=$4
    local filters=${5:-"tier,issue"}

    jq --arg filters "$filters" '
        # Takes field name (e.g., "tier", "issue") and field value (e.g., "official", "deprecated")
        # Returns formatted metric name like "tier_official_count"
        def metric_name(field_name; field_value):
          [field_name, (field_value | ascii_downcase), "count"] | join("_");

        # Takes field name, field value, and count, returns metric object
        def create_metric(field_name; field_value; count):
          {(metric_name(field_name; field_value)): count};

        # initialize metrics json with the number of extensions
        {
          extension_count: length
        } +

        # For each filter, generate the count for each value if enabled
        # group_by create groups for each unique value
        # create_metric() - Helper function to create consistent metric objects
        # length - Counts how many items are in each group
        # add combines the count objects
        (if ($filters | contains("tier")) then
          (group_by(.tier) | map(create_metric("tier"; .[0].tier; length)) | add)
        else {} end) +

        # collect the issues of all published version of the extension
        (if ($filters | contains("issue")) then
          ([.[] |
            select(.compliance) |
            [.compliance | to_entries[] | .value.issues[]?] | unique | .[]
          ] |
          group_by(.) |
          map(create_metric("issue"; .[0]; length)) | add // {})
        else {} end)
    ' $registry > $json_file

    # Convert JSON to Prometheus format
    jq -r --arg timestamp "${timestamp}" '
        to_entries[] | 
        .key as $metric_name |
        (.key | gsub("_count$"; "") | gsub("_"; " ")) as $description |
        .value as $count |
        [
          "# HELP registry_" + $metric_name + " Number of " + $description + " extensions.",
          "# TYPE registry_" + $metric_name + " counter",
          "registry_" + $metric_name + " " + ($count | tostring) + " " + $timestamp,
          ""
        ] | join("\n")
    ' $json_file > $prometheus_file
}

# Generate catalog from registry
#
# Iterates over the registry entry and generates a catalog entry for
# each import, output, and subcommand defined by the extension 
#
# input: registry file
# output: catalog file 
function generate_catalog() {
    local registry_file=$1
    local output_file=$2
    
    jq '
        # Creates a separate arrays of key-value pairs using import, output, and subcommand as keys
        # and the extension as value, and converts this array of key-value pairs to an object
        [
          .[] as $ext |
          if ($ext | has("imports")) and $ext.imports then
            $ext.imports[] | {key: ., value: $ext}
          else empty end
        ] +
        [
          .[] as $ext |
          if ($ext | has("outputs")) and $ext.outputs then
            $ext.outputs[] | {key: ., value: $ext}
          else empty end
        ] +
        [
          .[] as $ext |
          if ($ext | has("subcommands")) and $ext.subcommands then
            $ext.subcommands[] | {key: ("subcommand:" + .), value: $ext}
          else empty end
        ] | from_entries
    ' "$registry_file" > "$output_file"
}

function generate_for_dir() {
    local dir=$1
    local registry_file="${dir}/registry.json"

    if [[ ! -f "$registry_file" ]]; then
        return 0
    fi

    rm -rf "${dir}/"{tier,module}
    mkdir -p "${dir}/tier"
    mkdir -p "${dir}/module"

    $LOG "Starting generation of registry API files in ${dir}..."

    REGISTRY_FILE="$registry_file" BUILD_DIR="$dir" generate_module_files

    $LOG "Generating ${dir}/catalog.json..."
    generate_catalog "${registry_file}" "${dir}/catalog.json"

    for tier in "${TIERS[@]}"; do
        $LOG "Generating tier files for: ${tier} in ${dir}..."
        mkdir -p "${dir}/tier"
        jq --arg tier "$tier" '[.[] | select(.tier == $tier)]' "${registry_file}" > "${dir}/tier/${tier}.json"
        generate_catalog "${dir}/tier/${tier}.json" "${dir}/tier/${tier}-catalog.json"
        generate_metrics "${dir}/tier/${tier}.json" "${dir}/tier/${tier}-metrics.json" "${dir}/tier/${tier}-metrics.txt" "${TIMESTAMP}" "issue"
    done

    $LOG "Generating metrics for ${dir}..."
    generate_metrics "${registry_file}" "${dir}/metrics.json" "${dir}/metrics.txt" "${TIMESTAMP}"

    $LOG "Generation complete for ${dir}!"
}

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -b, --build-dir DIR   Specify build directory (default: ./build)"
    echo "  -h, --help            Show this help message"

}

# Parameters
TIERS=("official" "community")

# default log command to noop
LOG=":"

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
TEMPLATES_DIR="${SCRIPT_DIR}/api"

TIMESTAMP="$(date +%s)000"

# Check for required dependencies
if ! command -v gomplate >/dev/null 2>&1; then
    echo "Error: gomplate is required but not installed."
    echo "Install with: go install github.com/hairyhenderson/gomplate/v4/cmd/gomplate@latest"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed."
    echo "Install jq from your package manager."
    exit 1
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build-dir)
            BUILD_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -t|--timestamp)
             TIMESTAMP=$2
             shift 2
             ;;
        -v|--verbose)
            LOG="echo"
            shift 1
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

REGISTRY_FILE="${BUILD_DIR}/registry.json"

# Check if registry.json exists
if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "Error: registry.json not found at ${REGISTRY_FILE}"
    echo "Please ensure the registry.json file exists before running this script."
    exit 1
fi

# Generate v1 API files
generate_for_dir "${BUILD_DIR}"

# generate product/cloud-catalog.json to ensure backwards compatibility
mkdir -p "${BUILD_DIR}/product"
cp "${BUILD_DIR}/catalog.json" "${BUILD_DIR}/product/cloud-catalog.json"

# Generate v2 API files if registry-v2.json has been pre-generated into build/v2/
if [[ -f "${BUILD_DIR}/v2/registry.json" ]]; then
    $LOG "Found v2 registry, generating v2 API files..."
    generate_for_dir "${BUILD_DIR}/v2"
fi

$LOG "Generated files in: ${BUILD_DIR}"
