#!/bin/bash

set -euo pipefail

usage() {
    echo "find new versions in a local registry compared to the published version"
    echo ""
    echo "Usage: $0 [--ref BASE_URL] [--lint] [--checks CHECKS] [registry]"
    echo ""
    echo "Options:"
    echo "  --ref BASE_URL     URL for the reference registry (default: https://registry.k6.io/registry.json)"
    echo "  --lint             Also run xk6 lint on new versions"
    echo "  --checks CHECKS    Comma-separated list of checks to run (passed to xk6 lint --enable-only)"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "Arguments:"
    echo "  registry           Path to the new registry file (default: registry.json)"
}

# Find new versions in registry not present in the base registry
# produces an output like
# github.com/grafana/xk6-example:v1.1.0 v1.2.0
# $1 url to base registry
# $2 path to registry 
new_versions() {
    local base=$1
    local registry=$2

    # Get individual new module:version pairs, then group by module
    # jq produced a list of module:version lines for each version
    # comm -23 keeps only the lines that appears in the first file (local registry)
    local diff=$(comm -23 \
        <(jq -r '.[] | "\(.module):\(.versions[])"' "$registry" | sort) \
        <(curl -fsSL "$base" | jq -r '.[] | "\(.module):\(.versions[])"' | sort))

    if [[ -n "$diff" ]]; then
        # Group by module and join versions with spaces
        echo "$diff" | awk -F: '{modules[$1] = modules[$1] " " $2} END {for (m in modules) print m ":" modules[m]}' | sort
    fi
}

# Lint new versions using xk6 lint
# Takes the output from new_versions function and lints each extension
# $1 new versions string (format: "module:version" per line)
# $2 optional checks parameter (passed to xk6 lint --enable-only)
lint_versions() {
    local versions="$1"
    local checks="$2"
    local temp_dir
    local exit_code=0
    
    if [[ -z "$versions" ]]; then
        echo "No new versions to lint"
        return 0
    fi
    
    # process each module with the detected versions
    while IFS= read -r line; do
        # skip empty lines
        if [[ -z "$line" ]]; then
            continue
        fi
        
        # Parse module:version1 version2 version3
        local module=$(echo "$line" | cut -d':' -f1)
        local mod_versions=$(echo "$line" | cut -d':' -f2)
        
        # Skip linting for go.k6.io/k6 module
        if [[ "$module" == "go.k6.io/k6" ]]; then
            continue
        fi
        
        # Create temporary directory
        temp_dir=$(mktemp -d)
        
        # Clone repository
        # TODO: get the clone url from the registry
        if git clone "https://$module.git" "$temp_dir" &>/dev/null; then
            # Change to temp directory and checkout version
            pushd "$temp_dir" > /dev/null

            # Process each version for this module
            for version in $mod_versions; do
                echo -n "Linting $module:$version"
                
                if git checkout "$version" &>/dev/null; then
                    # Run xk6 lint and capture output
                    local lint_output
                    local lint_cmd="xk6 lint"
                    if [[ -n "$checks" ]]; then
                        lint_cmd="$lint_cmd --enable-only $checks"
                    fi
                    
                    if lint_output=$($lint_cmd 2>&1); then
                        echo "  ✓ passed"
                    else
                        echo "  ✗ failed"
                        echo "$lint_output" | sed 's/^/    /'
                        exit_code=1
                    fi
                else
                    echo "  ✗ - error checking out version"
                    exit_code=1
                fi
            done  # end of version loop

            popd > /dev/null
        else
            echo "  ✗ - error cloning repository"
            exit_code=1
        fi
        
        # Cleanup temp directory
        rm -rf "$temp_dir"
                
    done <<< "$versions"

    return $exit_code
}

# Default values
BASE_URL="https://registry.k6.io/registry.json"
REGISTRY=""
LINT=false
CHECKS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --ref)
            BASE_URL="$2"
            shift 2
            ;;
        --lint)
            LINT=true
            shift
            ;;
        --checks)
            CHECKS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [[ -z "$REGISTRY" ]]; then
                REGISTRY="$1"
            else
                echo "Too many arguments" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# Set default registry file if not provided
REGISTRY="${REGISTRY:-registry.json}"

if [[ ! -f "$REGISTRY" ]]; then
    echo "Error: Registry file '$REGISTRY' not found"
    exit 1
fi

# Get new versions and lint them
NEW_VERSIONS=$(new_versions $BASE_URL $REGISTRY)

if [[ -n "$NEW_VERSIONS" ]]; then
    echo "Found new versions:"
    echo "$NEW_VERSIONS" | sed 's/^/    /'
    echo ""
    
    # Lint the new versions if requested
    if [[ "$LINT" == true ]]; then
        echo "Linting new versions"
        lint_versions "$NEW_VERSIONS" "$CHECKS"
    fi
else
    echo "No new versions found"
fi
