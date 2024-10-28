#!/bin/bash

# Function to display usage information
usage() {
    echo "Usage: $0 [build|run|test] <kernel_version> [--source=<default|dcd>]"
    echo "  build: Build the Docker image"
    echo "  run: Run the Docker container"
    echo "  test: Run QEMU test with the built kernel"
    echo "  <kernel_version>: Linux kernel version (e.g., 5.15.0)"
    echo "  --source: Select kernel source (default: default)"
    echo "    default: Use kernel.org source"
    echo "    dcd: Use DCD kernel source"
    exit 1
}

# Check if at least two arguments are provided
if [ $# -lt 2 ]; then
    usage
fi

ACTION=$1
KERNEL_VERSION=$2
KERNEL_SOURCE="default"

# Parse additional arguments
for arg in "${@:3}"; do
    case $arg in
        --source=*)
            KERNEL_SOURCE="${arg#*=}"
            ;;
        *)
            echo "Unknown argument: $arg"
            usage
            ;;
    esac
done

# Validate kernel source
if [ "$KERNEL_SOURCE" != "default" ] && [ "$KERNEL_SOURCE" != "dcd" ]; then
    echo "Invalid kernel source: $KERNEL_SOURCE"
    usage
fi

# Function to build the Docker image
build_docker() {
    # Remove old stopped containers
    echo "Removing old stopped containers..."
    docker container prune -f

    # Build the Docker image with kernel source argument
    docker build \
        --build-arg KERNEL_VERSION=$KERNEL_VERSION \
        --build-arg KERNEL_SOURCE=$KERNEL_SOURCE \
        -t kernel-builder:$KERNEL_VERSION .
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
    
    # Get the actual kernel version from the output
    ACTUAL_KERNEL_VERSION=$(cat output/kernel_version.txt | cut -d= -f2)
    echo "Actual kernel version: $ACTUAL_KERNEL_VERSION"

    # Create a timestamped folder for the emulator files
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    EMULATOR_FOLDER="to_emulator_${TIMESTAMP}_${ACTUAL_KERNEL_VERSION}_${KERNEL_SOURCE}"
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
tar xzvf bzImage_$ACTUAL_KERNEL_VERSION.tar.gz

# Extract kernel modules
tar xjvf $ACTUAL_KERNEL_VERSION.tar.bz2

# Extract initramfs
tar xvf initramfs-$ACTUAL_KERNEL_VERSION.tar

echo "All files have been extracted successfully."
EOF

    # Make the script executable
    chmod +x "$EMULATOR_FOLDER/extract.sh"

    echo "Extraction script 'extract.sh' has been created in $EMULATOR_FOLDER"

    # Create a zip archive of the emulator folder
    zip -r "${EMULATOR_FOLDER}.zip" "$EMULATOR_FOLDER"

    echo "All files have been copied to $EMULATOR_FOLDER and zipped into ${EMULATOR_FOLDER}.zip"
}

# Function to run QEMU test
run_qemu_test() {
    # Find the latest folder (not zip file)
    latest_folder=$(ls -d to_emulator_*/ 2>/dev/null | grep -v '\.zip$' | sort -r | head -n1)
    if [ -z "$latest_folder" ]; then
        echo "No output folder found. Please run the container first."
        exit 1
    fi
    
    echo "Using folder: $latest_folder"
    cd "$latest_folder"
    
    # Get the actual kernel version from the folder name
    ACTUAL_KERNEL_VERSION=$(echo $latest_folder | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+[^_]*')
    
    # Extract files if they haven't been extracted yet
    if [ ! -f "bzImage" ]; then
        echo "Extracting files..."
        ./extract.sh
    fi
    
    # Download Ubuntu server image if not present
    UBUNTU_IMAGE="ubuntu-22.04-server-cloudimg-amd64.img"
    if [ ! -f "$UBUNTU_IMAGE" ]; then
        echo "Downloading Ubuntu server image..."
        wget "https://cloud-images.ubuntu.com/releases/22.04/release/$UBUNTU_IMAGE"
    else
        echo "Ubuntu server image already exists."
    fi

    # Create a larger image for QEMU with explicit backing format
    echo "Creating QEMU disk image..."
    qemu-img create -f qcow2 -F raw -b "$UBUNTU_IMAGE" ubuntu-test.qcow2 20G

    # Ensure the image was created
    if [ ! -f "ubuntu-test.qcow2" ]; then
        echo "Failed to create QEMU disk image"
        exit 1
    fi

    # Create CXL test files if they don't exist
    dd if=/dev/zero of=/tmp/cxltest.raw bs=1M count=512
    dd if=/dev/zero of=/tmp/lsa.raw bs=1M count=512

    echo "Starting QEMU..."
    # Run QEMU with updated CXL configuration
    qemu-system-x86_64 \
        -enable-kvm \
        -m 4G \
        -smp 2 \
        -kernel bzImage \
        -initrd initramfs-$ACTUAL_KERNEL_VERSION.img \
        -append "console=ttyS0 root=/dev/ram0 rw" \
        -drive file=ubuntu-test.qcow2,format=qcow2 \
        -nographic \
        -machine q35,cxl=on \
        -object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/cxltest.raw,size=512M \
        -object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/lsa.raw,size=512M \
        -device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.1,hdm_for_passthrough=true \
        -device cxl-rp,port=0,bus=cxl.1,id=root_port13,chassis=0,slot=2 \
        -device cxl-type3,bus=root_port13,memdev=cxl-mem1,lsa=cxl-lsa1,id=cxl-pmem0,sn=0xabcd \
        -M cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=8k \
        -device pcie-root-port,id=net_port,bus=pcie.0,addr=0x1 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0,bus=net_port

    echo "QEMU test completed."
}

# Main logic
case $ACTION in
    build)
        build_docker
        ;;
    run)
        run_docker
        ;;
    test)
        run_qemu_test
        ;;
    *)
        usage
        ;;
esac
