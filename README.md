# DOCKER_KERNEL_BUILD

This project provides a Docker-based system for building Linux kernels with specific configurations, including CXL support. It automates the process of downloading, configuring, building, and packaging the kernel and its modules.

## Prerequisites

- Docker installed on your system
- Bash shell
- QEMU with KVM support (for testing)

## Usage

1. Clone this repository:
   ```
   git clone https://github.com/your-username/DOCKER_KERNEL_BUILD.git
   cd DOCKER_KERNEL_BUILD
   ```

2. Make the build script executable:
   ```
   chmod +x build_run.sh
   ```

3. Build the Docker image:
   ```
   # For default kernel from kernel.org:
   ./build_run.sh build <kernel_version> --source=default

   # For DCD kernel:
   ./build_run.sh build <kernel_version> --source=dcd
   ```

4. Run the Docker container to build the kernel and create output files:
   ```
   ./build_run.sh run <kernel_version>
   ```

5. Test the built kernel and initramfs using QEMU:
   ```
   ./build_run.sh test <kernel_version>
   ```

## Kernel Sources

The project supports two kernel sources:
- **default**: Standard Linux kernel from kernel.org
- **dcd**: DCD (Data Center Development) kernel with additional features

## Output

After running the container, you'll find:

- A `to_emulator_<timestamp>_<kernel_version>` folder containing:
  - `bzImage_<kernel_version>.tar.gz`: Compressed kernel image
  - `<kernel_version>.tar.bz2`: Compressed kernel modules
  - `initramfs-<kernel_version>.tar`: Compressed initial RAM filesystem
  - `extract.sh`: Script to extract the above files
  - `kernel_version.txt`: File containing the actual kernel version

- A `to_emulator_<timestamp>_<kernel_version>.zip` file containing the above folder

## QEMU Testing

The QEMU test runs the built kernel with CXL support. It uses the following configuration:

- 4GB of RAM
- 2 CPU cores
- KVM acceleration (if available)
- CXL Type 3 device with 512MB of memory
- Ubuntu 22.04 server cloud image as root filesystem
- Network support with port forwarding (host:2222 -> guest:22)

## CXL Configuration

The kernel is built with the following CXL features enabled:
- CXL Bus Support
- CXL Port and Memory Device Support
- CXL ACPI Support
- CXL Region Support
- CXL Memory Raw Commands
- CXL Suspend/Resume Support

## Customization

- To modify kernel configurations, edit the `container_build_script.sh` and adjust the `sed` commands in the "Configure the kernel for x86_64" section
- To change the build process or output, modify the `Dockerfile` and the `build_run.sh` script
- To adjust the QEMU test configuration, modify the `run_qemu_test` function in the `build_run.sh` script

## Troubleshooting

1. Ensure Docker is properly installed and running on your system
2. Check that you have sufficient disk space for the build process
3. Verify that you have the necessary permissions to run Docker commands
4. For QEMU testing:
   - Ensure QEMU is installed with KVM support
   - Verify your system supports virtualization
   - Check that the required disk space is available for the Ubuntu server image

## Contributing

Contributions to improve this project are welcome. Please submit pull requests or open issues on the GitHub repository.

## License

[Specify your license here]
