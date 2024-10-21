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
    # Remove old stopped containers
    echo "Removing old stopped containers..."
    docker container prune -f

    # Build the Docker image
    docker build --build-arg KERNEL_VERSION=$KERNEL_VERSION -t kernel-builder:$KERNEL_VERSION .
}

# Function to run the Docker container
run_docker() {
    # Remove old output folder if it exists
    if [ -d "$(pwd)/output" ]; then
        echo "Removing old output directory..."
        rm -rf $(pwd)/output
    fi

    # Remove old archives if they exist
    if ls *.tar.gz *.tar.bz2 1> /dev/null 2>&1; then
        echo "Removing old archives..."
        rm -f *.tar.gz *.tar.bz2
    fi

    # Create a new output directory
    mkdir -p $(pwd)/output
    docker run --rm -v $(pwd)/output:/output kernel-builder:$KERNEL_VERSION
    echo "Contents of the output directory:"
    ls -lR $(pwd)/output

    # Create a timestamped folder for the emulator files
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    EMULATOR_FOLDER="to_emulator_$TIMESTAMP"
    mkdir -p "$EMULATOR_FOLDER"

    # Copy compressed files to the emulator folder
    cp $(pwd)/output/*.tar.gz "$EMULATOR_FOLDER/" 2>/dev/null || echo "No .tar.gz files found"
    cp $(pwd)/output/*.tar.bz2 "$EMULATOR_FOLDER/" 2>/dev/null || echo "No .tar.bz2 files found"
    cp $(pwd)/output/*.tar "$EMULATOR_FOLDER/" 2>/dev/null || echo "No .tar files found"

    # Create an extraction script
    cat << EOF > "$EMULATOR_FOLDER/extract.sh"
#!/bin/bash

# Exit on any error
set -e

# Extract bzImage
tar xzvf bzImage_$KERNEL_VERSION.tar.gz

# Extract kernel modules
tar xjvf $KERNEL_VERSION.tar.bz2

# Extract initramfs
tar xvf initramfs-$KERNEL_VERSION.tar

echo "All files have been extracted successfully."
EOF

    # Make the script executable
    chmod +x "$EMULATOR_FOLDER/extract.sh"

    echo "Extraction script 'extract.sh' has been created in $EMULATOR_FOLDER"

    # Create a zip archive of the emulator folder
    zip -r "${EMULATOR_FOLDER}.zip" "$EMULATOR_FOLDER"

    echo "All files have been copied to $EMULATOR_FOLDER and zipped into ${EMULATOR_FOLDER}.zip"
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
