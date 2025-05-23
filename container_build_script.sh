#!/bin/bash

set -e  # Exit on failure

# Arguments
KERNEL_VERSION=$1
KERNEL_SOURCE=$2

# Set base directory
BASE_DIR="/kernel"

# Create required directories
mkdir -p "$BASE_DIR/install_dir"
mkdir -p "$BASE_DIR/mod_dir"
mkdir -p "$BASE_DIR/initramfs"

# Set installation paths
INSTALL_PATH="$BASE_DIR/install_dir"
INSTALL_MOD_PATH="$BASE_DIR/mod_dir"

# Function to download and extract default kernel
get_default_kernel() {
    cd "$BASE_DIR"
    wget https://cdn.kernel.org/pub/linux/kernel/v$(echo $KERNEL_VERSION | cut -d. -f1).x/linux-$KERNEL_VERSION.tar.xz
    tar xf linux-$KERNEL_VERSION.tar.xz
    mv linux-$KERNEL_VERSION linux-kernel
}

# Function to download and extract DCD kernel
get_dcd_kernel() {
    cd "$BASE_DIR"
    if [[ "${KERNEL_VERSION:0:3}" != "dcd" ]]; then
        echo "Error: For DCD kernel source, KERNEL_VERSION must start with 'dcd'"
        exit 1
    fi

    echo "Downloading DCD kernel for version $KERNEL_VERSION..."
    ZIP_FILE="${KERNEL_VERSION}.zip"
    wget "https://github.com/weiny2/linux-kernel/archive/refs/heads/${KERNEL_VERSION}.zip" -O "$ZIP_FILE" || \
    curl -L "https://github.com/weiny2/linux-kernel/archive/refs/heads/${KERNEL_VERSION}.zip" -o "$ZIP_FILE"

    if [ ! -f "$ZIP_FILE" ]; then
        echo "Failed to download DCD kernel"
        exit 1
    fi

    echo "Extracting DCD kernel..."
    unzip -q "$ZIP_FILE"
    DIR_NAME="linux-kernel-${KERNEL_VERSION}"
    if [ ! -d "$DIR_NAME" ]; then
        echo "Extraction failed: directory $DIR_NAME not found"
        exit 1
    fi
    mv "$DIR_NAME" linux-kernel
}

# Download and extract kernel based on source selection
case $KERNEL_SOURCE in
    "default")
        get_default_kernel
        ;;
    "dcd")
        get_dcd_kernel
        ;;
    *)
        echo "Invalid kernel source: $KERNEL_SOURCE"
        exit 1
        ;;
esac

cd "$BASE_DIR/linux-kernel"

# Configure the kernel for x86_64
make x86_64_defconfig
sed -i 's/# CONFIG_CXL_BUS is not set/CONFIG_CXL_BUS=y/' .config
sed -i 's/# CONFIG_CXL_PCI is not set/CONFIG_CXL_PCI=y/' .config
sed -i 's/# CONFIG_CXL_MEM_RAW_COMMANDS is not set/CONFIG_CXL_MEM_RAW_COMMANDS=y/' .config
sed -i 's/# CONFIG_CXL_ACPI is not set/CONFIG_CXL_ACPI=y/' .config
sed -i 's/# CONFIG_CXL_MEM is not set/CONFIG_CXL_MEM=y/' .config
sed -i 's/# CONFIG_CXL_PORT is not set/CONFIG_CXL_PORT=y/' .config
sed -i 's/# CONFIG_CXL_SUSPEND is not set/CONFIG_CXL_SUSPEND=y/' .config
sed -i 's/# CONFIG_CXL_REGION is not set/CONFIG_CXL_REGION=y/' .config

# Compile and install kernel
make -j$(nproc) bzImage
make -j$(nproc) modules
make INSTALL_PATH="$INSTALL_PATH" install
make INSTALL_MOD_PATH="$INSTALL_MOD_PATH" modules_install

# Get the actual kernel version
ACTUAL_KERNEL_VERSION=$(make kernelversion)
echo "Actual kernel version: $ACTUAL_KERNEL_VERSION"

# Copy bzImage to install_dir folder
cp arch/x86/boot/bzImage "$INSTALL_PATH/bzImage"

# Create necessary directories for initramfs
mkdir -p /lib/modules/$ACTUAL_KERNEL_VERSION
cp -r "$INSTALL_MOD_PATH/lib/modules/$ACTUAL_KERNEL_VERSION"/* /lib/modules/$ACTUAL_KERNEL_VERSION/

# Generate initramfs
cd "$BASE_DIR/initramfs"
mkinitramfs -o "$BASE_DIR/initramfs/initramfs-$ACTUAL_KERNEL_VERSION.img" $ACTUAL_KERNEL_VERSION

# Create compressed archives
cd "$BASE_DIR"
tar czvf bzImage_$ACTUAL_KERNEL_VERSION.tar.gz -C "$INSTALL_PATH" .
tar cjvf $ACTUAL_KERNEL_VERSION.tar.bz2 -C "$INSTALL_MOD_PATH" .
tar czvf initramfs-$ACTUAL_KERNEL_VERSION.tar -C "$BASE_DIR/initramfs" .

# Create a timestamped folder for the emulator files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EMULATOR_FOLDER="$BASE_DIR/to_emulator_$TIMESTAMP"
mkdir -p "$EMULATOR_FOLDER"

# Copy compressed files to the emulator folder
mv bzImage_$ACTUAL_KERNEL_VERSION.tar.gz $ACTUAL_KERNEL_VERSION.tar.bz2 initramfs-$ACTUAL_KERNEL_VERSION.tar "$EMULATOR_FOLDER/"

# Create an extraction script with proper file names
cat << EOF > "$EMULATOR_FOLDER/extract.sh"
#!/bin/bash
set -e

echo "Starting extraction process..."

# Extract bzImage
echo "Extracting kernel image..."
if [ -f "bzImage_$ACTUAL_KERNEL_VERSION.tar.gz" ]; then
    tar xzvf bzImage_$ACTUAL_KERNEL_VERSION.tar.gz
else
    echo "Error: bzImage_$ACTUAL_KERNEL_VERSION.tar.gz not found"
    exit 1
fi

# Extract kernel modules
echo "Extracting kernel modules..."
if [ -f "$ACTUAL_KERNEL_VERSION.tar.bz2" ]; then
    tar xjvf $ACTUAL_KERNEL_VERSION.tar.bz2
else
    echo "Error: $ACTUAL_KERNEL_VERSION.tar.bz2 not found"
    exit 1
fi

# Extract initramfs
echo "Extracting initramfs..."
if [ -f "initramfs-$ACTUAL_KERNEL_VERSION.tar" ]; then
    tar xvf initramfs-$ACTUAL_KERNEL_VERSION.tar
else
    echo "Error: initramfs-$ACTUAL_KERNEL_VERSION.tar not found"
    exit 1
fi

echo "All files have been extracted successfully."
echo "Kernel version: $ACTUAL_KERNEL_VERSION"
echo "Available files:"
ls -l
EOF

chmod +x "$EMULATOR_FOLDER/extract.sh"

# Save the kernel version for reference
echo "ACTUAL_KERNEL_VERSION=$ACTUAL_KERNEL_VERSION" > "$EMULATOR_FOLDER/kernel_version.txt"

echo "Build completed. Output is in $EMULATOR_FOLDER"
