# Test Assignment: CentOS Stream 8 Kernel Build Prototype

Disclaimer: This is a technical task for CloudLinux. It is not intended for production use, and is a prototype for demonstration purposes only.

# Main sources used:
- CentOS Wiki: [I Need the Kernel Source](https://wiki.centos.org/HowTos(2f)I_need_the_Kernel_Source.html)
- CentOS Wiki: [I Need to Build a Custom Kernel](https://wiki.centos.org/HowTos(2f)Custom_Kernel.html)

# Quick Start:

## How to Run the Normal Build (Task 1 + 2)

```sh
# Build the Go tool
make -C kernel-builder-go/
# Then run the build (specify arch if needed, e.g., --arch arm64)
./build-stream8-kernel --srpm https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm --out ./out
```

## How to Generate a Patched SRPM and Build It (Task 3)

```sh
# Build the Go tools
make -C kernel-builder-go/
make -C patch-srpm-go/
# First, create the patched SRPM
./patch-stream8-srpm --srpm https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm --out ./srcout --patches ./patches
# Then, build the kernel using the patched SRPM
./build-stream8-kernel ./srcout/kernel-*.patched.src.rpm ./out
```

The produced RPMs and SRPMs will be in the `out/` directory.

Below are more details about the implementation of each task.

# Overview

Given a CentOS Stream 8 kernel source RPM, the goal is to build this kernel in a Docker-based environment and make it easy to run the build and collect the resulting RPMs.


The project was separated into three tasks:

## Task 1: Prototype: Build the kernel SRPM in Docker

Files involved: `Dockerfile`, `entrypoint.sh`, `start_docker_build.sh`

This prototype demonstrates a simple Dockerfile that sets up a CentOS Stream 8 environment with necessary dependencies to build the kernel from SRPM. The `entrypoint.sh` script handles the unpacking of the SRPM, building the kernel, and copying the resulting RPMs to an output directory.

The Dockerfile uses CentOS Stream 8, which has reached its End-of-Life (EOL) status, so the repository URLs have been updated to point to the vault.

There are comments in all of the involved files, describing some choices made during the implementation.

Since I am building on Apple Silicon (ARM64) machines, I needed to either use cross-compilation or build using an ARM64 CentOS Stream 8 environment. Since the cross-compilation takes a long time, I have been building for Linux ARM64 architecture using Docker's `--platform` option, which doesn't use emulation and is much faster.

To run the build, use the `start_docker_build.sh` script, providing the path to the kernel SRPM and optionally the target architecture (defaults to host architecture).

Considerations and TODOs:
- The Docker image installs a lot of dependencies so that I wouldn't need to install them every time. The list of packages is copied from the CentOS wiki pages. If the Docker image would be used for building other kernels, it might be better to minimize the installed packages to only those needed for building the kernel. The `dnf builddep` command can detect and install the required dependencies.
- I had a problem with `dnf builddep kernel.src.rpm` not finding some dependencies, so I used `dnf builddep rpmbuild/SRPMS/kernel.src.rpm` additionally after extracting the SRPM. I am not sure if this is an actual issue but it ensures all dependencies are properly installed. I would investigate this further if this were a production-level tool.
- The wiki pages ask to uncomment the definition of `buildid` and set a custom value. I did that since I wasn't sure if I can safely add this line to the file. I would spend a bit more time on properly appending this line to its correct location, even if it didn't exist in the spec file.
- I would spend time to implement ccache to speed up repeated builds and not start from scratch each time, since each build takes around 30 minutes even with no cross-compilation.

Commit hash: 77d26af76472ad8b9b6d023bd1626594241576d1

## Task 2: Prototype: Go build tool

This prototype demonstrates a simple Go program that automates the Docker build process. It accepts command-line arguments for the kernel SRPM path, output directory, and target architecture. The program constructs and executes the appropriate Docker command to run the build inside the container.

Files involved: `kernel-builder-go/*`

Usage: `build-stream8-kernel <src.rpm|url> <outfolder> [arch]`

Commit hash: 96efbb5dacccbf70066f9b543994f90615de30e4

## Task 3: Prototype: Create a patched SRPM and rebuild

The task was to create a patched version of the CentOS Stream 8 kernel SRPM with a specific patch applied, and then rebuild the kernel using this patched SRPM.

Upstream Linux commits:
80e648042e512d5a767da251d44132553fe04ae0
f90fff1e152dedf52b932240ebbd670d83330eca

I have created two flows that achieve this. The first flow used the `build-stream8-kernel` Go tool from Task 2 and extends it to handle patching together with building. The tool accepts a directory containing patch files, applies them to the kernel source after unpacking the SRPM, and then builds the kernel with the applied patches.

But I realized that it's not exactly what the tasks asks for, since it builds the kernel directly with patches applied, rather than creating a new patched SRPM. So, I created the second, better flow.

The second flow is a new tool called `patch-srpm`, which creates a new patched SRPM by applying the specified patches to the original SRPM. This tool unpacks the original SRPM, applies the patches, and then repacks it into a new SRPM. The resulting patched SRPM can then be built using the existing `build-stream8-kernel` tool.

Files involved: `patch-srpm-go/*`

Usage: `patch-stream8-srpm --srpm <src.rpm|url> --out <outfolder> --patches <patches_dir> [--arch <arch>]`

As part of this task, I found out that the second commit causes conflicts when applying the patch. Therefore, I had to manually fix the patch to ensure it applies cleanly. Instructions for manually fixing patches are provided in the `patch-conflict-fixing/README.md` file.


