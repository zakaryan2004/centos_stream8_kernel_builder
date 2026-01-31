# Sources used (for reference):
# https://wiki.centos.org/HowTos(2f)I_need_the_Kernel_Source.html
# https://wiki.centos.org/HowTos(2f)Custom_Kernel.html

# Use the official CentOS 8 image as the base
FROM quay.io/centos/centos:stream8


USER root

# As root, install necessary development tools and libraries
# CentOS 8 has reached EOL, so repository URLs must be updated to the vault
# It's also good practice to clean up DNF cache to reduce image size
#
# Powertools is for dwarves libbpf-devel libmnl-devel libtraceevent-devel libbabeltrace-devel 
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
    dnf update -y && \
    # dnf groupinstall -y "Development Tools" && \
    dnf install -y 'dnf-command(config-manager)' && \
    dnf config-manager --set-enabled powertools && \
    # dnf -y install epel-release && \
    dnf install -y ncurses-devel hmaccalc zlib-devel binutils-devel elfutils-libelf-devel sudo && \
    # Most of these are not fully required for any kernel build,
    # but copied them from CentOS wiki for completeness
    # The dnf builddep would install missing deps for the specific kernel SRPM
    # I included these here so we can have a more complete base image for future uses
    # If we want to minimize image size, we can remove those
    dnf install -y asciidoc audit-libs-devel bash bc binutils binutils-devel bison diffutils elfutils \
    elfutils-devel elfutils-libelf-devel findutils flex gawk gcc gettext gzip hmaccalc hostname java-devel \
    m4 make module-init-tools ncurses-devel net-tools newt-devel numactl-devel openssl patch pciutils-devel \
    perl perl-ExtUtils-Embed pesign python3-devel python3-docutils redhat-rpm-config rpm-build sh-utils tar \
    xmlto xz zlib-devel git libtraceevent-devel perl-generators && \
    dnf install -y bpftool clang dwarves kabi-dw libbabeltrace-devel libbpf-devel libcap-devel libcap-ng-devel libmnl-devel libnl3-devel llvm openssl-devel rsync && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# Create a non-root user and group
RUN groupadd kernelgroup && \
    useradd kernelbuilder -G kernelgroup && \
    echo "kernelbuilder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Switch to the non-root user
USER kernelbuilder

WORKDIR /home/kernelbuilder

# As an ordinary (non-root) user, create a directory for building the kernel
RUN mkdir -p ~/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
RUN echo '%_topdir %(echo $HOME)/rpmbuild' > ~/.rpmmacros

COPY --chown=kernelbuilder:kernelbuilder entrypoint.sh /home/kernelbuilder/entrypoint.sh
RUN chmod +x /home/kernelbuilder/entrypoint.sh

# This script will do the build. It's better to do the build there
# so we can have a base Docker image ready to go and build any kernel SRPM later
ENTRYPOINT ["/home/kernelbuilder/entrypoint.sh"]


########### OUTDATED STEPS BELOW, KEPT FOR REFERENCE AND TESTING ONLY
# Copy our downloaded kernel SRPM from the host to the container
# COPY kernel-4.18.0-448.el8.src.rpm ./

# As root, install the missing dependencies
# USER root
# RUN dnf builddep -y kernel-4.18.0-448.el8.src.rpm

# USER kernelbuilder

# Extract the kernel source code as non-root user
# RUN rpm -i kernel-4.18.0-448.el8.src.rpm
# RUN rpm -i https://vault.centos.org/8-stream/BaseOS/Source/SPackages/kernel-4.18.0-448.el8.src.rpm

# WORKDIR /home/kernelbuilder/rpmbuild/SPECS

# Now unpack the kernel source tarball
# RUN rpmbuild -bp --define "_smp_mflags -j8" --target=x86_64 kernel.spec
# RUN rpmbuild -bp --define "_smp_mflags -j8" kernel.spec

# The kernel source tree will now be found under the ~/rpmbuild/BUILD/kernel*/linux*/ directory
# Done HowTos(2f)I_need_the_Kernel_Source.html

# Starting HowTos(2f)Custom_Kernel.html

# RUN rpmbuild -bb --define "_smp_mflags -j8" --target=x86_64 kernel.spec
# Since I am building on Apple Silicon (ARM), cross-compilation is slow
# so I am omitting the --target flag to let rpmbuild choose the right one
# (it will build for aarch64)
# TODO: Use ccache to speed up repeated builds and not start from scratch each time
# since each build takes around 30 minutes even with no cross-compilation
# RUN rpmbuild -bb --define "_smp_mflags -j8" kernel.spec
