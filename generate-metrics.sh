#!/bin/bash

set -euo pipefail

# K6 Extension Registry Prometheus Metrics Generator
#
# This script generates Prometheus metrics in text format from registry.json
# using only bash and jq.
#
# Generated metrics include:
# Phase 1 - Totals by tier and grade:
# - Total extensions count
# - Extensions by tier (official, community)  
# - Extensions by grade (A, B, C, D)
# - Extensions by tier-grade combinations
#
# Phase 2 - Totals by compliance issues:
# - Extensions by issue type (smoke, types, examples, build, replace)
# - Extensions by tier-issue combinations

function usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --filters         List of filters (grade, community, issues). Defaults to all"
    echo "  -j, --json FILE       Generate JSON metrics file at specified path (optional)"
    echo "  -m, --metrics FILE    Use specified metrics file path (default: build/metrics.txt)"
    echo "  -r, --registry FILE   Use specified registry file path (default: build/registry.json)"
    echo "  -h, --help            Show this help message"
}

# Generates prometheus metrics from a registry file
# Arguments
# $1 registry file (input)
# $2 filter (e.g. grade, tier, issue)
# $3 jq query for extracting a list of values for the category
# $4 timestamp for metrics
# $5 metrics file (output)
function generate_prometheus() {
  local registry_file="$1"
  local filter="$2"
  local query="$3"
  local timestamp="$4"
  local metrics_file="$5"

  jq -r "$query" "$registry_file" | sort | uniq -c | while read count value; do
    value=$(echo "$value" | tr '[:upper:]' '[:lower:]')
    cat >> "$metrics_file" << EOF
# HELP registry_${filter}_${value}_count Number of ${value}-${filter} extensions.
# TYPE registry_${filter}_${value}_count counter
registry_${filter}_${value}_count $count $timestamp

EOF
  done
}

#
# Generates a JSON file containing metrics data from a source metrics file.
#
# This function reads metrics from the global METRICS_FILE variable, where each line
# contains space-separated values (name, count, timestamp). It creates a JSON object
# with metric names as keys and their counts as values.
#
# Parameters:
#   $1 input metrics file
#   $2 output json file
#
# Input Format:
#   Prometheus metrics format
#
# Output:
#   {
#     "metric_name1": count1,
#     "metric_name2": count2,
#     ...
#   }
#
#
function generate_json() {
    local metrics_file="$1"
    local metrics_json_file="$2"

    {
        printf "{\n"
        sep=""
        while IFS= read -r line; do
            # Skip empty lines and lines starting with #
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Split line into words
            read -r name count timestamp <<< "$line"
            
            # Skip if we don't have at least name and count
            [[ -z "$name" || -z "$count" ]] && continue
            
            # Remove 'registry_' prefix from metric name for JSON output
            name="${name#registry_}"

            # Write metric with separator
            printf "%s  \"%s\": %s" "$sep" "$name" "$count"
            sep=$',\n'
        done < "$metrics_file"
        printf '\n}\n'
    } > "$metrics_json_file"
    
    echo "JSON metrics generated successfully at: ${metrics_json_file}"
}

# Configuration

# Queries by filter
declare -A QUERIES
QUERIES["tier"]='.[] | .tier' 
QUERIES["grade"]='.[] | select(.compliance) | .compliance.grade'
QUERIES["issue"]='.[] | select(.compliance) | .compliance.issues[]?'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
REGISTRY_FILE="${BUILD_DIR}/registry.json"
METRICS_FILE="${BUILD_DIR}/metrics.txt"
METRICS_JSON_FILE=""
FILTERS="tier,grade,issue"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--filters)
            FILTERS=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -j|--json)
            METRICS_JSON_FILE="$2"
            shift 2
            ;;
        -m|--metrics)
            METRICS_FILE="$2"
            shift 2
            ;;
        -r|--registry)
            REGISTRY_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if registry.json exists
if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "Error: registry.json not found at ${REGISTRY_FILE}"
    echo "Please ensure the registry.json file exists before running this script."
    exit 1
fi

echo "Generating Prometheus metrics from ${REGISTRY_FILE}..."

# Get current timestamp in milliseconds
TIMESTAMP=$(date +%s)000

# Start building the metrics file
cat > "$METRICS_FILE" << EOF
# HELP registry_extension_count The total number of extensions.
# TYPE registry_extension_count counter
registry_extension_count $(jq 'length' "$REGISTRY_FILE") $TIMESTAMP

EOF

# Generate metrics by filter
for FILTER in ${FILTERS//,/ }; do
   echo "Generating $FILTER metrics..." 
   generate_prometheus "$REGISTRY_FILE" $FILTER "${QUERIES[$FILTER]}" "$TIMESTAMP" "$METRICS_FILE"
done

echo "Prometheus metrics generated successfully at: ${METRICS_FILE}"

if [[ ! -z $METRICS_JSON_FILE ]]; then
   generate_json $METRICS_FILE $METRICS_JSON_FILE
fi