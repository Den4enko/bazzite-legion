#!/usr/bin/env bash
set -oeux pipefail

# 1. Get the exact bazzite kernel version inside the build container
KERNEL_VERSION=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel | head -n 1)

# 2. Temporarily install build dependencies
rpm-ostree install kernel-devel git make gcc

# --- STAGE A: BUILD AND INSTALL LENOVO-LEGION-LINUX KERNEL MODULE ---
git clone https://github.com/johnfanv2/LenovoLegionLinux.git /tmp/legion
cd /tmp/legion/kernel_module

# FIX 3: Bypass the wrapper Makefile which hardcodes the GitHub Actions runner's kernel.
# We call the kernel's Kbuild system directly, pointing it to the container's kernel headers.
make -C /usr/src/kernels/${KERNEL_VERSION} M=$(pwd) modules

# Copy the compiled .ko file to the system extra modules directory
MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${MODULE_DIR}"
cp legion-laptop.ko "${MODULE_DIR}/"

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
