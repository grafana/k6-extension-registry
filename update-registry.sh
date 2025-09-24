#!/bin/bash

# K6 Extension Registry Update Script
#
# This script updates the k6 extension registry with new versions.
# It assumes inputs have already been validated by the workflow.
#
# Usage:
#   ./update-registry.sh --module <module> --version <version> [--registry-path <path>]
#
# Example:
#   ./update-registry.sh --module github.com/grafana/xk6-sql --version v1.2.3

set -euo pipefail

# Default configuration
REGISTRY_PATH="registry.yaml"

# Initialize variables
MODULE=""
VERSION=""

# Function to show usage
usage() {
    cat << EOF
K6 Extension Registry Update Script

Usage: $0 [OPTIONS]

Options:
  -m, --module MODULE           The module name to update (e.g., github.com/grafana/xk6-sql)
  -v, --version VERSION         The version to add (e.g., v1.2.3)
  -r, --registry-path PATH      Path to registry.yaml file (default: registry.yaml)
  -h, --help                    Show this help message

Examples:
  $0 --module github.com/grafana/xk6-sql --version v1.2.3

EOF
}

# Function to validate inputs
validate_inputs() {    
    # Validate module format (should be a valid Go module path)
    if [[ ! "$MODULE" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
        echo "Error: Invalid module format: $MODULE"
        echo "Module must be a valid Go module path"
        exit 1
    fi
    
    # Validate version format (should be semver with v prefix)
    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
        echo "Error: Invalid version format: $VERSION (expected semver with 'v' prefix)"
        echo "Examples: v1.0.0, v1.2.3-beta.1, v2.0.0+build.123"
        exit 1
    fi
}

# Function to update registry with new version
update_registry() {
    # Check if registry file exists
    if [[ ! -f "$REGISTRY_PATH" ]]; then
        echo "Error: Registry file $REGISTRY_PATH does not exist"
        exit 1
    fi

    # Check if module exists in registry
    MODULE_INDEX=$(yq eval ".[] | select(.module == \"$MODULE\") | path | .[0]" "$REGISTRY_PATH")

    if [[ -z "$MODULE_INDEX" ]]; then
        echo "Error: Module $MODULE not found in registry"
        echo "Please add the module to the registry first by creating a PR with the module definition."
        exit 1
    fi

    # Check if version already exists
    VERSION_EXISTS=$(yq eval ".[$MODULE_INDEX].versions[] | select(. == \"$VERSION\")" "$REGISTRY_PATH")

    if [[ -n "$VERSION_EXISTS" ]]; then
        echo "Version $VERSION already exists for module $MODULE"
        exit 0
    fi

    # Add the new version to the module
    yq eval ".[$MODULE_INDEX].versions += [\"$VERSION\"]" -i "$REGISTRY_PATH"

    echo "Successfully added version $VERSION to module $MODULE"

    # Show the updated versions for this module
    echo "Current versions for $MODULE:"
    yq eval ".[$MODULE_INDEX].versions[]" "$REGISTRY_PATH"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--module)
            MODULE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -r|--registry-path)
            REGISTRY_PATH="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$MODULE" ]]; then
    echo "Error: Missing required parameter: --module"
    usage
    exit 1
fi

if [[ -z "$VERSION" ]]; then
    echo "Error: Missing required parameter: --version"
    usage
    exit 1
fi

validate_inputs

update_registry
