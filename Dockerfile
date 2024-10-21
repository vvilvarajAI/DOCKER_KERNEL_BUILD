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
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /kernel

# Copy the build script into the container
COPY container_build_script.sh /kernel/

# Make the script executable
RUN chmod +x /kernel/container_build_script.sh

# The Linux kernel version will be passed as a build argument
ARG KERNEL_VERSION

# Run the build script
RUN /kernel/container_build_script.sh $KERNEL_VERSION

# Set the output directory as a volume
VOLUME /kernel/to_emulator_*

# Add a command to copy files from the latest to_emulator folder to /output
CMD latest_folder=$(ls -d /kernel/to_emulator_* | sort -r | head -n1) && \
    cp -r $latest_folder/* /output && \
    echo "Files copied to /output" && \
    ls -l /output
