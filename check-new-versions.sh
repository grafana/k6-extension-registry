#!/bin/bash

set -euo pipefail

log() {
    if [[ ! -z "${VERBOSE}" ]]; then
        echo $*
    fi
}

usage() {
   cat << EOF
find new versions in a local registry compared to the published version

Usage: $0 [--ref BASE_URL] [--lint] [--checks CHECKS] [registry]

Options:
    --ref BASE_URL     URL for the reference registry in json format (default: https://registry.k6.io/registry.json)
    --lint             Also run xk6 lint on new versions
    --lint-flags FLAGS List of flags to passed to xk6 lint. For example '--enable-only build'
    --help, -h         Show this help message
    --verbose, -v      verbose output

Arguments:
    registry           Path to the new registry file (default: registry.yaml)

Return codes
    0: no changes found
    1: changes found
    2: lint failed
EOF
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
    # yq produced a list of module:version lines for each version
    # comm -23 keeps only the lines that appears in the first file (local registry)
    local diff=$(comm -23 \
        <(yq eval '.[] | .module + ":" + .versions[]' "$registry" | sort) \
        <(curl -fsSL "$base" | yq eval -P | yq eval '.[] | .module + ":" + .versions[]' - | sort))

    if [[ -n "$diff" ]]; then
        # Group by module and join versions with spaces
        echo "$diff" | awk -F: '{modules[$1] = modules[$1] " " $2} END {for (m in modules) print m ":" modules[m]}' | sort
    fi
}

# Lint the versions of a module
# it is handled differently as xk6 cannot lint k6
# $1 module name
# $2 github repository
# $3 versions
# $4 lint command
#
# returns
#   0 if lint passes
#   1 if lint fails
lint_module() {
    local module=$1
    local repo=$2
    local versions=$3
    local lint_cmd=$4

    # Create temporary directory
    temp_dir=$(mktemp -d)

    # TODO: get the clone url from the registry
    if git clone "$repo" "$temp_dir" &>/dev/null; then
        # Change to temp directory and checkout version
        pushd "$temp_dir" > /dev/null

        # Process each version for this module
        for version in $versions; do
            log -n "Linting $module:$version"

            if git checkout "$version" &>/dev/null; then
                if lint_output=$($lint_cmd 2>&1); then
                    log "  ✓ passed"
                else
                    log "  ✗ failed"
                    log "$lint_output" | sed 's/^/    /'
                    exit_code=1
                fi
            else
                log "  ✗ - error checking out version"
                exit_code=1
            fi
        done  # end of version loop

        popd > /dev/null
    else
        log "  ✗ - error cloning repository"
        exit_code=1
    fi

    # Cleanup temp directory
    rm -rf "$temp_dir"

    return $exit_code
}

# Lint new versions. 
# Extensions are linted with xk6 and the given flags.
# k6 is not linted, only the version is checked to exist.
# Takes the output from new_versions function and lints each extension
# $1 new versions string (format: "module:version" per line)
# $2 optional lint flags
# returns:
#   0 if lint passes
#   1 if lint fails
lint_versions() {
    local versions="$1"
    local flags="$2"
    local temp_dir
    local exit_code=0

    if [[ -z "$versions" ]]; then
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

        # k6 is handled differently
        if [[ "$module" == "go.k6.io/k6" ]]; then
            repo="https://github.com/grafana/k6.git"
            # don't do nothing for linting k6, just check the version exists
            lint_cmd="true"
        else
            repo="https://$module.git"
            lint_cmd="xk6 lint $flags"
        fi

        lint_module $module $repo "$mod_versions" $lint_cmd || exit_code=1

    done <<< "$versions"

    return $exit_code
}

# Default values
BASE_URL="https://registry.k6.io/registry.json"
REGISTRY=""
LINT=false
LINT_FLAGS=""
VERBOSE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --lint-flags)
            LINT_FLAGS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --lint)
            LINT=true
            shift
            ;;
        --ref)
            BASE_URL="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
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
REGISTRY="${REGISTRY:-registry.yaml}"

if [[ ! -f "$REGISTRY" ]]; then
    log "Error: Registry file '$REGISTRY' not found"
    exit 2
fi

# Get new versions and lint them
NEW_VERSIONS=$(new_versions $BASE_URL $REGISTRY)

if [[ -n "$NEW_VERSIONS" ]]; then
    log "Found new versions:"
    echo "$NEW_VERSIONS"

    # Lint the new versions if requested
    if [[ "$LINT" == true ]]; then
        lint_versions "$NEW_VERSIONS" "$LINT_FLAGS"
    fi
else
    log "No new versions found"
fi
