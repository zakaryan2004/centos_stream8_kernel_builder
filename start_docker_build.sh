#!/bin/bash
set -e

# This is temporary and will be rewritten in Go
# This script is the very beginning. You should run this manually
# This script will download or copy the SRPM, build the Docker image,
# and run the container to perform the build.

SRPM_INPUT="$1"
ARCH="${2:-aarch64}"
if [ -z "$SRPM_INPUT" ]; then
    echo "Error: No SRPM provided"
    exit 1
fi

if [[ "$SRPM_INPUT" == http* ]]; then
    echo ">>> Downloading SRPM from URL..."
    curl "$SRPM_INPUT" --create-dirs -o src/kernel.src.rpm
else
    echo ">>> Using local SRPM..."
    # check if the file exists
    if [ ! -f "$SRPM_INPUT" ]; then
        echo "Error: Local SRPM file '$SRPM_INPUT' does not exist."
        exit 1
    fi
    # ignore error (if cp source and dest are identical)
    cp "$SRPM_INPUT" src/kernel.src.rpm  || true
fi

echo ">>> Building Docker Image..."
docker build --platform linux/$ARCH -t kernel-builder .

echo ">>> Running Docker Container..."
docker run --platform linux/$ARCH --rm -v "$(pwd)/src":/src \
    -v "$(pwd)/output":/home/kernelbuilder/output kernel-builder

echo ">>> Build complete. RPMs are in the 'output' dir"