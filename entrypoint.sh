#!/bin/bash
set -e

cp "/src/kernel.src.rpm" rpmbuild/SRPMS/kernel.src.rpm

# Install build dependencies
echo ">>> Installing build dependencies from SRPM..."
sudo dnf builddep -y rpmbuild/SRPMS/kernel.src.rpm

# Extract the kernel source code
echo ">>> Extracting kernel source from SRPM..."
rpm -i rpmbuild/SRPMS/kernel.src.rpm

# From my experience, sometimes we still have missing dependencies
# that are not listed in the SRPM builddeps.
# Example: opencsd-devel is needed at least in aarch64 builds,
# but dnf builddep -y rpmbuild/SRPMS/kernel.src.rpm would not install it
echo ">>> Installing additional dependencies from kernel.spec..."
sudo dnf builddep -y rpmbuild/SPECS/kernel.spec

# Unpack the kernel source tarball
echo ">>> Unpacking kernel source tarball..."
cd /home/kernelbuilder/rpmbuild/SPECS
rpmbuild -bp kernel.spec

# Building
echo ">>> Building..."
# --define "_smp_mflags -j8" but rpmbuild will autodetect cpu count
rpmbuild -bb kernel.spec

# Mock build
# echo ">>> Mock building RPMs..."
# cd /home/kernelbuilder/
# mkdir -p rpmbuild/RPMS/aarch64
# touch rpmbuild/RPMS/aarch64/kernel.rpm

# Copy built RPMs
echo ">>> Copying RPMs to output folder..."
cp -r /home/kernelbuilder/rpmbuild/RPMS/* /home/kernelbuilder/output/

echo ">>> Build Complete. Copied RPMs to output folder."