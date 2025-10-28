#!/bin/bash

set -e

TEMP_DIR=$(mktemp -d)

cleanup() {
        rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Copy test/registry.json to temporary directory
cp test/registry.json "$TEMP_DIR/"

# Generate files. Use a fixed timestamp for metrics to allow comparison
./generate-api-files.sh -b "$TEMP_DIR" -t "1757407780000"

# Compare generated files
if ! diff -r -x registry.yaml test "$TEMP_DIR"; then
        echo "FAILURE: Generated files differ from expected output"
        exit 1
fi

echo "SUCCESS: Generated files match expected output"
exit 0
