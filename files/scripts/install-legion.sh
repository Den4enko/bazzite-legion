#!/usr/bin/env bash
set -oeux pipefail

# 1. Bazzite uses the standard "kernel" package name internally
KERNEL_VERSION=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel | head -n 1)

# 2. Temporarily install build dependencies (using standard kernel-devel)
rpm-ostree install kernel-devel git make gcc

# --- STAGE A: BUILD AND INSTALL LENOVO-LEGION-LINUX KERNEL MODULE ---
git clone https://github.com/johnfanv2/lenovo-legion-linux.git /tmp/legion
cd /tmp/legion/kernel_module

# Compile the module strictly for the current container kernel version
make KDIR=/usr/src/kernels/${KERNEL_VERSION}

# Copy the compiled .ko file to the system extra modules directory
MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${MODULE_DIR}"
cp lenovo-legion-linux.ko "${MODULE_DIR}/"

# Update kernel module dependencies
depmod -a "${KERNEL_VERSION}"


# --- STAGE B: INTEGRATE PLASMAVANTAGE AND ITS ROOT SERVICE ---
git clone https://gitlab.com/Scias/plasmavantage.git /tmp/plasmavantage

# 1. Copy the widget globally into the system
mkdir -p /usr/share/plasma/plasmoids/com.gitlab.scias.plasmavantage
cp -r /tmp/plasmavantage/* /usr/share/plasma/plasmoids/com.gitlab.scias.plasmavantage/

# 2. Install the system systemd unit
cp /tmp/plasmavantage/contents/util/plasmavantage-noroot.service /usr/lib/systemd/system/plasmavantage-noroot.service

# Create a symlink to enable the service persistently
mkdir -p /usr/lib/systemd/system/multi-user.target.wants
ln -s ../plasmavantage-noroot.service /usr/lib/systemd/system/multi-user.target.wants/plasmavantage-noroot.service


# --- STAGE C: ABSOLUTE CLEANUP ---
# Remove source files and build packages to keep the OSTree layer minimal
rm -rf /tmp/legion /tmp/plasmavantage
rpm-ostree uninstall kernel-devel git make gcc
