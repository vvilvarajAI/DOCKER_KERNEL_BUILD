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
    zip \
    initramfs-tools \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /kernel

# Copy the build script into the container
COPY container_build_script.sh /kernel/

# Make the script executable
RUN chmod +x /kernel/container_build_script.sh

# The Linux kernel version and source will be passed as build arguments
ARG KERNEL_VERSION
ARG KERNEL_SOURCE=default

# Run the build script with source selection
RUN /kernel/container_build_script.sh $KERNEL_VERSION $KERNEL_SOURCE

# Set the output directory as a volume
VOLUME /kernel/to_emulator_*

# Add a command to copy files from the latest to_emulator folder to /output
CMD latest_folder=$(ls -d /kernel/to_emulator_* | sort -r | head -n1) && \
    ACTUAL_KERNEL_VERSION=$(cat /kernel/kernel_version.txt | cut -d= -f2) && \
    cp -r $latest_folder/* /output && \
    echo "ACTUAL_KERNEL_VERSION=$ACTUAL_KERNEL_VERSION" > /output/kernel_version.txt && \
    echo "Files copied to /output" && \
    ls -l /output
