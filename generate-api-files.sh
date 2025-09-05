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
# - Grade (A, B, C, D, E, F)
# - Module: generates per-module extension metadata files

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -b, --build-dir DIR   Specify build directory (default: ./build)"
    echo "  -h, --help            Show this help message"

}

# Parameters
GRADES=("A" "B" "C" "D" "E" "F")
TIERS=("official" "community")

# default log command to noop
LOG=":"
VERBOSE=""

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
        -v|--verbose)
            LOG="echo"
            VERBOSE="-v"
            shift 1
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
    $LOG "Generating module extension files..."
    
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

# Generate metrics for a registry
# Generates the total number of extensions and the counter for each filter
# 
# Parameters
# $1 input registry file)
# $2 output metrics file in json format
# $3 output metrics file in prometheus format
# $4 filters. Defaults to all (tier,grade,issue)
function generate_metrics() {
  local registry=$1
  local json_file=$2
  local prometheus_file=$3
  local filters=${4:-"tier,grade,issue"}

jq --arg filters "$filters" '{
  extension_count: length
} +

# For each filter, generate the count for each value if enabled
# group_by create groups for each unique value
# map(...) - Transforms each group into a count object
# .[0] - Gets the first (and representative) issue name from each group
# ascii_downcase - Converts to lowercase for consistent naming
# \(...) - String interpolation to create the metric key
# length - Counts how many issues are in each group
# add combines the count objects

(if ($filters | contains("tier")) then
  (group_by(.tier) | map({"tier_\(.[0].tier | ascii_downcase)_count": length}) | add)
else {} end) +

(if ($filters | contains("grade")) then
  ([.[] | select(.compliance.grade)] | group_by(.compliance.grade) | map({"grade_\(.[0].compliance.grade | ascii_downcase)_count": length}) | add)
else {} end) +

(if ($filters | contains("issue")) then
  ([.[] | select(.compliance.issues) | .compliance.issues[]] | group_by(.) | map({"issue_\(.[0] | ascii_downcase)_count": length}) | add)
else {} end)
' $registry > $json_file

# Convert JSON to Prometheus format
jq -r --arg timestamp "$(date +%s)000" '
to_entries[] | 
"# HELP registry_\(.key) Number of \(.key | gsub("_count$"; "") | gsub("_"; " ")) extensions.
# TYPE registry_\(.key) counter
registry_\(.key) \(.value) \($timestamp)
"
' $json_file > $prometheus_file
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
        # Step 1: Create separate arrays for import and output entries
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
        ] |
        
        # Step 2: Convert key-value pairs to object
        from_entries
    ' "$registry_file" > "$output_file"
}

# Check if registry.json exists
if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "Error: registry.json not found at ${REGISTRY_FILE}"
    echo "Please ensure the registry.json file exists before running this script."
    exit 1
fi

$LOG "Starting generation of registry API files..."

# Generate module-specific files
generate_module_files

# Generate main catalog
$LOG "Generating ${BUILD_DIR}/catalog.json..."
generate_catalog "${REGISTRY_FILE}" "${BUILD_DIR}/catalog.json"

# Generate tier-based files
for tier in "${TIERS[@]}"; do
    $LOG "Generating tier files for: ${tier}..."
    
    # Create tier directory
    mkdir -p "${BUILD_DIR}/tier"
    
    # Generate tier registry file (as per spec: /tier/{tier}.json)
    jq --arg tier "$tier" '[.[] | select(.tier == $tier)]' "${REGISTRY_FILE}" > "${BUILD_DIR}/tier/${tier}.json"
    
    # Generate tier cataLOG file (as per spec: /tier/{tier}-catalog.json)
    generate_catalog "${BUILD_DIR}/tier/${tier}.json" "${BUILD_DIR}/tier/${tier}-catalog.json"

    # Generate metrics for tier
    generate_metrics "${BUILD_DIR}/tier/${tier}.json" "${BUILD_DIR}/tier/${tier}-metrics.json" "${BUILD_DIR}/tier/${tier}-metrics.txt" "grade,issue"
done

# Generate grade-based files
for grade in "${GRADES[@]}"; do
    $LOG "Generating grade files for: ${grade}..."
    
    # Filter registry by grade using jq (handle missing compliance fields)
    jq --arg grade "$grade" '[.[] | select(.compliance and .compliance.grade == $grade)]' "${REGISTRY_FILE}" > "${BUILD_DIR}/grade/${grade}.json"
    
    # Generate grade catalog file
    generate_catalog  "${BUILD_DIR}/grade/${grade}.json" "${BUILD_DIR}/grade/${grade}-catalog.json"
done

$LOG "Generating metrics"
generate_metrics  "${BUILD_DIR}/registry.json" "${BUILD_DIR}/metrics.json" "${BUILD_DIR}/metrics.txt"

$LOG "Generation complete!"
$LOG "Generated files in: ${BUILD_DIR}"
if [[ ! -z $VERBOSE ]];then
   tree -L 2 ${BUILD_DIR}
fi
