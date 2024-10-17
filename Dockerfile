FROM ubuntu:20.04

# Install necessary packages
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    libncurses5-dev \
    flex \
    bison \
    openssl \
    libssl-dev \
    dkms \
    libelf-dev \
    libudev-dev \
    libpci-dev \
    libiberty-dev \
    autoconf \
    bc \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /kernel

# The Linux kernel version will be passed as a build argument
ARG KERNEL_VERSION

# Download and extract the kernel source
RUN wget https://cdn.kernel.org/pub/linux/kernel/v$(echo $KERNEL_VERSION | cut -d. -f1).x/linux-$KERNEL_VERSION.tar.xz \
    && tar xf linux-$KERNEL_VERSION.tar.xz \
    && cd linux-$KERNEL_VERSION

# Configure the kernel for x86_64
RUN cd linux-$KERNEL_VERSION \
    && make x86_64_defconfig \
    && sed -i 's/# CONFIG_CXL_BUS is not set/CONFIG_CXL_BUS=y/' .config \
    && sed -i 's/# CONFIG_CXL_PCI is not set/CONFIG_CXL_PCI=y/' .config \
    && sed -i 's/# CONFIG_CXL_MEM_RAW_COMMANDS is not set/CONFIG_CXL_MEM_RAW_COMMANDS=y/' .config \
    && sed -i 's/# CONFIG_CXL_ACPI is not set/CONFIG_CXL_ACPI=y/' .config \
    && sed -i 's/# CONFIG_CXL_MEM is not set/CONFIG_CXL_MEM=y/' .config \
    && sed -i 's/# CONFIG_CXL_PORT is not set/CONFIG_CXL_PORT=y/' .config \
    && sed -i 's/# CONFIG_CXL_SUSPEND is not set/CONFIG_CXL_SUSPEND=y/' .config \
    && sed -i 's/# CONFIG_CXL_REGION is not set/CONFIG_CXL_REGION=y/' .config

# Build the kernel and modules, and install modules
RUN cd linux-$KERNEL_VERSION \
    && make -j$(nproc) \
    && make modules \
    && make modules_install INSTALL_MOD_PATH=/tmp/kernel-modules

# Create a directory to store the output
RUN mkdir -p /kernel_output

# Copy the bzImage and modules to the output directory
RUN cp linux-$KERNEL_VERSION/arch/x86/boot/bzImage /kernel_output/ \
    && cp -r /tmp/kernel-modules/lib/modules /kernel_output/

# Set the output directory as a volume
VOLUME /kernel_output

# Add a command to copy files from /kernel_output to /output
CMD cp -r /kernel_output/* /output && echo "Files copied to /output"
