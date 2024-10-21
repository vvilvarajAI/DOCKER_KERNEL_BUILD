#!/bin/bash

set -e  # Exit on failure

# The kernel version will be passed as an argument
KERNEL_VERSION=$1

# Set base directory
BASE_DIR="/kernel"

# Create required directories
mkdir -p "$BASE_DIR/install_dir"
mkdir -p "$BASE_DIR/mod_dir"
mkdir -p "$BASE_DIR/initramfs"

# Set installation paths
INSTALL_PATH="$BASE_DIR/install_dir"
INSTALL_MOD_PATH="$BASE_DIR/mod_dir"

# Download and extract the kernel source
cd "$BASE_DIR"
wget https://cdn.kernel.org/pub/linux/kernel/v$(echo $KERNEL_VERSION | cut -d. -f1).x/linux-$KERNEL_VERSION.tar.xz
tar xf linux-$KERNEL_VERSION.tar.xz
cd linux-$KERNEL_VERSION

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

# Copy bzImage to install_dir folder
cp arch/x86/boot/bzImage "$INSTALL_PATH/bzImage"

# Create necessary directories for initramfs
mkdir -p /lib/modules/$KERNEL_VERSION
cp -r "$INSTALL_MOD_PATH/lib/modules/$KERNEL_VERSION"/* /lib/modules/$KERNEL_VERSION/

# Generate initramfs
cd "$BASE_DIR/initramfs"
mkinitramfs -o "$BASE_DIR/initramfs/initramfs-$KERNEL_VERSION.img" $KERNEL_VERSION

# Create compressed archives
cd "$BASE_DIR"
tar czvf bzImage_$KERNEL_VERSION.tar.gz -C "$INSTALL_PATH" .
tar cjvf $KERNEL_VERSION.tar.bz2 -C "$INSTALL_MOD_PATH" .
tar czvf initramfs-$KERNEL_VERSION.tar -C "$BASE_DIR/initramfs" .

# Create a timestamped folder for the emulator files
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EMULATOR_FOLDER="$BASE_DIR/to_emulator_$TIMESTAMP"
mkdir -p "$EMULATOR_FOLDER"

# Copy compressed files to the emulator folder
mv bzImage_$KERNEL_VERSION.tar.gz $KERNEL_VERSION.tar.bz2 initramfs-$KERNEL_VERSION.tar "$EMULATOR_FOLDER/"

# Create an extraction script
cat << 'EOF' > "$EMULATOR_FOLDER/extract.sh"
#!/bin/bash
set -e
tar xzvf bzImage_*.tar.gz
tar xjvf *.tar.bz2
tar xvf initramfs-*.tar
echo "All files have been extracted successfully."
EOF

chmod +x "$EMULATOR_FOLDER/extract.sh"

echo "Build completed. Output is in $EMULATOR_FOLDER"
