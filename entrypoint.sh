#!/bin/bash
set -e

cp "/src/kernel.src.rpm" rpmbuild/SRPMS/kernel.src.rpm

# Install build dependencies
echo ">>> Installing build dependencies from SRPM..."
sudo dnf builddep -y rpmbuild/SRPMS/kernel.src.rpm

# Extract the kernel source code
echo ">>> Extracting kernel source from SRPM..."
rpm -i rpmbuild/SRPMS/kernel.src.rpm

# If --patchonly is provided, check if there are patches to apply
if [ "$1" == "--patchonly" ]; then
    if [ ! -d "/patches" ] || ! ls /patches/*.patch 1>/dev/null 2>&1; then
        echo "Error: --patchonly specified but no patches found in /patches"
        exit 1
    fi
fi

# If there are patches (even in normal build), copy them and modify spec file
if [ -d "/patches" ] && ls /patches/*.patch 1>/dev/null 2>&1; then
    echo ">>> Copying patches to SOURCES..."
    cp /patches/*.patch /home/kernelbuilder/rpmbuild/SOURCES/

    echo ">>> Modifying kernel.spec to include patches..."
    cd /home/kernelbuilder/rpmbuild/SPECS
    cp kernel.spec kernel.spec.distro

    # Uncomment and set buildid (TODO check if this ALWAYS exists)
    sed -i 's/^.*define buildid.*$/%define buildid .patched/' kernel.spec

    # Start patch numbering from 40000 to avoid conflicts with other patches
    PATCH_NUM=40000
    PATCH_DECLARATIONS=""
    PATCH_APPLICATIONS=""
    
    for patch in /patches/*.patch; do
        PATCH_NAME=$(basename "$patch")
        PATCH_DECLARATIONS="${PATCH_DECLARATIONS}Patch${PATCH_NUM}: ${PATCH_NAME}\n"
        PATCH_APPLICATIONS="${PATCH_APPLICATIONS}ApplyOptionalPatch ${PATCH_NAME}\n"
        PATCH_NUM=$((PATCH_NUM + 1))
    done

    # Insert declarations after "# empty final patch to facilitate testing of kernel patches"
    sed -i "/# empty final patch to facilitate testing of kernel patches/a\\${PATCH_DECLARATIONS}" kernel.spec

    # Insert applications before "ApplyOptionalPatch linux-kernel-test.patch"
    sed -i "/ApplyOptionalPatch linux-kernel-test.patch/i\\${PATCH_APPLICATIONS}" kernel.spec

    echo ">>> Patches configured in kernel.spec"
    cd /home/kernelbuilder
fi

# From my experience, sometimes we still have missing dependencies
# that are not listed in the SRPM builddeps.
# Example: opencsd-devel is needed at least in aarch64 builds,
# but dnf builddep -y rpmbuild/SRPMS/kernel.src.rpm would not install it
echo ">>> Installing additional dependencies from kernel.spec..."
sudo dnf builddep -y rpmbuild/SPECS/kernel.spec

# Unpack the kernel source tarball
echo ">>> Unpacking kernel source tarball..."
cd /home/kernelbuilder/rpmbuild/SPECS
# -bp is Build Prep. We do this even for --patchonly to make sure the patches apply properly
rpmbuild -bp kernel.spec

if [ "$1" == "--patchonly" ]; then
    echo ">>> Repackaging modified SRPM..."
    rm /home/kernelbuilder/rpmbuild/SRPMS/kernel.src.rpm # delete the original
    rpmbuild -bs kernel.spec # -bs is Build Source
    
    echo ">>> Copying new SRPM to output folder..."
    cp /home/kernelbuilder/rpmbuild/SRPMS/*.src.rpm /home/kernelbuilder/output/
    echo ">>> Patch-only build complete. Copied patched SRPM to output folder."
else
    echo ">>> Building Binary RPMs..."
    # --define "_smp_mflags -j8" but rpmbuild will autodetect cpu count
    rpmbuild -bb kernel.spec # -bb is Build Binary

    # Mock build (to quicky test output copying)
    # echo ">>> Mock building RPMs..."
    # cd /home/kernelbuilder/
    # mkdir -p rpmbuild/RPMS/aarch64
    # touch rpmbuild/RPMS/aarch64/kernel.rpm
    
    echo ">>> Copying RPMs to output folder..."
    cp -r /home/kernelbuilder/rpmbuild/RPMS/* /home/kernelbuilder/output/
    echo ">>> Build Complete. Copied RPMs to output folder."
fi
