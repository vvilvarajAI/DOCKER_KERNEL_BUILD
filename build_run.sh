#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [build|run] <kernel_version>"
    echo "  build: Build the Docker image"
    echo "  run: Run the Docker container"
    echo "  <kernel_version>: Linux kernel version (e.g., 5.15.0)"
    exit 1
}

# Check if at least two arguments are provided
if [ $# -lt 2 ]; then
    usage
fi

ACTION=$1
KERNEL_VERSION=$2

# Function to build the Docker image
build_docker() {
    docker build --build-arg KERNEL_VERSION=$KERNEL_VERSION -t kernel-builder:$KERNEL_VERSION .
}

# Function to run the Docker container
run_docker() {
    mkdir -p $(pwd)/output
    docker run --rm -v $(pwd)/output:/output kernel-builder:$KERNEL_VERSION
    echo "Contents of the output directory:"
    ls -R $(pwd)/output
}

# Main logic
case $ACTION in
    build)
        build_docker
        ;;
    run)
        run_docker
        ;;
    *)
        usage
        ;;
esac
