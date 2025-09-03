#!/bin/bash

set -euo pipefail

# K6 Extension Registry API File Generator
#
# This script generates various json files from a registry.json following the structure of the API
# described in openapi.yaml.
# The generation process transforms the registry array into multiple catalog formats with different
# filtering and structure requirements:
#
# - Input: registry.json (array of extension objects)
# - Output: various catalog.json (key-value object where keys are import/output names)
#
# Each extension can generate multiple catalog entries based on its imports/outputs arrays:
# - Extension with imports: ["k6/x/sql", "k6/x/database"] creates 2 catalog entries
# - Extension with outputs: ["prometheus", "metrics"] creates 2 catalog entries  
# - Extension with both imports AND outputs creates entries for all combinations
#
# Extensions are filtered by:
# - Tier (official, community) 
# - Grade (A, B, C, D, E, F)
# - Module: generates per-module extension metadata files
#
# The script uses gomplate with templates to handle:
# - JSON escaping and structure consistency
# - Pre-filtered registry data for efficiency

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -b, --build-dir DIR   Specify build directory (default: ./build)"
    echo "  -h, --help            Show this help message"

}

# Parameters
GRADES=("A" "B" "C" "D" "E" "F")
TIERS=("official" "community")

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
TEMPLATES_DIR="${SCRIPT_DIR}/api"
REGISTRY_FILE="${BUILD_DIR}/registry.json"

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
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Create build directory structure
mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/tier"
mkdir -p "${BUILD_DIR}/grade"
mkdir -p "${BUILD_DIR}/module"

# Function to generate k6 registry grade badge
generate_k6_badge() {
    local grade="$1"
    local output_file="$2"
        
    # Convert to uppercase and validate
    grade=$(echo "$grade" | tr '[:lower:]' '[:upper:]')
    if [[ ! "$grade" =~ ^[A-F]$ ]]; then
        echo "Error: Invalid grade '$grade'. Must be A-F." >&2
        return 1
    fi
    
    # Generate SVG using gomplate template with environment variable
    GRADE="$grade" gomplate \
        --file "${TEMPLATES_DIR}/grade-badge.svg.tpl" \
        --out "$output_file"
}

# Function to generate module extension files
generate_module_files() {
    echo "Generating module extension files..."
    
    # Process each extension directly with jq, creating one file per module
    jq -r '.[] | "\(.module)|\(. | tostring)"' "${REGISTRY_FILE}" | \
    while IFS='|' read -r module extension_json; do
        if [[ -n "$module" ]]; then
            # Create directory for module
            local module_dir="${BUILD_DIR}/module/${module}"
            mkdir -p "${module_dir}"
            
            # Write extension.json directly
            echo "$extension_json" | jq . > "${module_dir}/extension.json"
            
            # Generate grade badge if module has compliance grade
            local grade
            grade=$(echo "$extension_json" | jq -r '.compliance.grade // empty')
            if [[ -n "$grade" && "$grade" != "null" ]]; then
                generate_k6_badge "$grade" "${module_dir}/grade.svg"
            fi
        fi
    done
}

# Check if registry.json exists
if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "Error: registry.json not found at ${REGISTRY_FILE}"
    echo "Please ensure the registry.json file exists before running this script."
    exit 1
fi

echo "Starting generation of registry API files..."

# Generate module-specific files
generate_module_files

# Generate main catalog
echo "Generating ${BUILD_DIR}/catalog.json..."
gomplate -f "${TEMPLATES_DIR}/catalog.json.tpl" -t helpers="${TEMPLATES_DIR}/helpers.tpl" -c "registry=${REGISTRY_FILE}" | jq . > "${BUILD_DIR}/catalog.json"

# Generate tier-based files
for tier in "${TIERS[@]}"; do
    echo "Generating tier files for: ${tier}..."
    
    # Create tier directory
    mkdir -p "${BUILD_DIR}/tier"
    
    # Generate tier registry file (as per spec: /tier/{tier}.json)
    jq --arg tier "$tier" '[.[] | select(.tier == $tier)]' "${REGISTRY_FILE}" > "${BUILD_DIR}/tier/${tier}.json"
    
    # Generate tier catalog file (as per spec: /tier/{tier}-catalog.json)
    gomplate -f "${TEMPLATES_DIR}/catalog.json.tpl" -t helpers="${TEMPLATES_DIR}/helpers.tpl" -c "registry=${BUILD_DIR}/tier/${tier}.json" | jq . > "${BUILD_DIR}/tier/${tier}-catalog.json"
done

# Generate grade-based files
for grade in "${GRADES[@]}"; do
    echo "Generating grade files for: ${grade}..."
    
    # Filter registry by grade using jq (handle missing compliance fields)
    jq --arg grade "$grade" '[.[] | select(.compliance and .compliance.grade == $grade)]' "${REGISTRY_FILE}" > "${BUILD_DIR}/grade/${grade}.json"
    
    # Generate grade catalog file
    gomplate -f "${TEMPLATES_DIR}/catalog.json.tpl" -t helpers="${TEMPLATES_DIR}/helpers.tpl" -c "registry=${BUILD_DIR}/grade/${grade}.json" | jq . > "${BUILD_DIR}/grade/${grade}-catalog.json"
done

echo "Generation complete!"
echo "Generated files in: ${BUILD_DIR}"
tree -L 2 ${BUILD_DIR}
