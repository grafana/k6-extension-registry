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

# Generate catalog from registry
#
# Iterates over the registry entry and generates a catalog entry for
# each import and output defined by the extension 
#
# input: registry file
# output: catalog file 
function generate_catalog() {
    local registry_file=$1
    local output_file=$2
    
    jq '
        # Creates a separate arrays of key-value pairs using import and output as keys
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
        ] | from_entries
    ' "$registry_file" > "$output_file"
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

# Create api directory structure
rm -rf  "${BUILD_DIR}/"{tier,module}
mkdir -p "${BUILD_DIR}/tier"
mkdir -p "${BUILD_DIR}/module"

$LOG "Starting generation of registry API files..."

# Generate module-specific files
generate_module_files

# Generate main catalog
$LOG "Generating ${BUILD_DIR}/catalog.json..."
generate_catalog "${REGISTRY_FILE}" "${BUILD_DIR}/catalog.json"

# generate product/cloud-catalog.json to ensure backwards compatibility
mkdir -p "${BUILD_DIR}/product"
cp "${BUILD_DIR}/catalog.json" "${BUILD_DIR}/product/cloud-catalog.json"

# Generate tier-based files
for tier in "${TIERS[@]}"; do
    $LOG "Generating tier files for: ${tier}..."
    
    # Create tier directory
    mkdir -p "${BUILD_DIR}/tier"
    
    # Generate tier registry file (as per spec: /tier/{tier}.json)
    jq --arg tier "$tier" '[.[] | select(.tier == $tier)]' "${REGISTRY_FILE}" > "${BUILD_DIR}/tier/${tier}.json"
    
    # Generate tier cataLOG file (as per spec: /tier/{tier}-catalog.json)
    generate_catalog "${BUILD_DIR}/tier/${tier}.json" "${BUILD_DIR}/tier/${tier}-catalog.json"
done

$LOG "Generation complete!"
$LOG "Generated files in: ${BUILD_DIR}"
