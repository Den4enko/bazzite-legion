#!/usr/bin/env bash
set -oeux pipefail

# 1. Get the exact bazzite kernel version inside the build container
KERNEL_VERSION=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel | head -n 1)

# 2. gcc, make, and kernel-devel are ALREADY in the Bazzite base image!
# We only need to install git to clone the repositories (keeping it permanently).
rpm-ostree install git

# --- STAGE A: BUILD AND INSTALL LENOVO-LEGION-LINUX KERNEL MODULE ---
git clone https://github.com/johnfanv2/LenovoLegionLinux.git /tmp/legion
cd /tmp/legion/kernel_module

# Bypass the wrapper Makefile and compile directly against the container's kernel
make -C /usr/src/kernels/${KERNEL_VERSION} M=$(pwd) modules

# Copy the compiled .ko file to the system extra modules directory
MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${MODULE_DIR}"
cp legion-laptop.ko "${MODULE_DIR}/"

# Update kernel module dependencies
depmod -a "${KERNEL_VERSION}"


# --- STAGE B: INTEGRATE PLASMAVANTAGE AND ITS ROOT SERVICE ---
git clone https://gitlab.com/Scias/plasmavantage.git /tmp/plasmavantage

# 1. Copy the widget globally into the system (the actual plasmoid is inside the 'package' dir)
mkdir -p /usr/share/plasma/plasmoids/com.gitlab.scias.plasmavantage
cp -r /tmp/plasmavantage/package/* /usr/share/plasma/plasmoids/com.gitlab.scias.plasmavantage/

# 2. Install the system systemd unit from the correct path
cp /tmp/plasmavantage/package/contents/util/plasmavantage-noroot.service /usr/lib/systemd/system/plasmavantage-noroot.service

# Create a symlink to enable the service persistently
mkdir -p /usr/lib/systemd/system/multi-user.target.wants
ln -s ../plasmavantage-noroot.service /usr/lib/systemd/system/multi-user.target.wants/plasmavantage-noroot.service


# --- STAGE C: ABSOLUTE CLEANUP ---
# Remove source files ONLY (leaving git installed in the base system)
rm -rf /tmp/legion /tmp/plasmavantage
