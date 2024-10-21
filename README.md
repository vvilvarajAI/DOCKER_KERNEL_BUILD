# DOCKER_KERNEL_BUILD

This project provides a Docker-based system for building Linux kernels with specific configurations, including CXL support. It automates the process of downloading, configuring, building, and packaging the kernel and its modules.

## Prerequisites

- Docker installed on your system
- Bash shell

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

3. Build the Docker image (replace `<kernel_version>` with your desired Linux kernel version, e.g., 6.11.3):
   ```
   ./build_run.sh build <kernel_version>
   ```

4. Run the Docker container to build the kernel and create output files:
   ```
   ./build_run.sh run <kernel_version>
   ```

## Output

After running the container, you'll find:

- A `to_emulator_<timestamp>` folder containing:
  - `bzImage_<kernel_version>.tar.gz`: Compressed kernel image
  - `<kernel_version>.tar.bz2`: Compressed kernel modules
  - `initramfs-<kernel_version>.tar`: Compressed initial RAM filesystem
  - `extract.sh`: Script to extract the above files

- A `to_emulator_<timestamp>.zip` file containing the above folder

## Customization

- To modify kernel configurations, edit the Dockerfile and adjust the `sed` commands in the "Configure the kernel for x86_64" section.
- To change the build process or output, modify the Dockerfile and the `build_run.sh` script as needed.

## Troubleshooting

If you encounter any issues:

1. Ensure Docker is properly installed and running on your system.
2. Check that you have sufficient disk space for the build process.
3. Verify that you have the necessary permissions to run Docker commands.

## Contributing

Contributions to improve this project are welcome. Please submit pull requests or open issues on the GitHub repository.

## License

[Specify your license here]
