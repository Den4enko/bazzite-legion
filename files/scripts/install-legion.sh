#!/usr/bin/env bash
set -oeux pipefail

# Get exact kernel version
KERNEL_VERSION=$(rpm -q --qf "%{VERSION}-%{RELEASE}.%{ARCH}" kernel | head -n 1)

# Install build dependencies
rpm-ostree install git

# --- STAGE A: KERNEL MODULE ---
git clone https://github.com/johnfanv2/LenovoLegionLinux.git /tmp/legion
cd /tmp/legion/kernel_module

# Build and install module
make -C /usr/src/kernels/${KERNEL_VERSION} M=$(pwd) modules
MODULE_DIR="/usr/lib/modules/${KERNEL_VERSION}/extra"
mkdir -p "${MODULE_DIR}"
cp legion-laptop.ko "${MODULE_DIR}/"
depmod -a "${KERNEL_VERSION}"

# --- STAGE B: LENOVO LEGION GUI & POLKIT ---
cd /tmp/legion/python/legion_linux

# Install Python GUI
python3 -m pip install --prefix=/usr --break-system-packages .

# Copy assets globally
mkdir -p /usr/share/applications /usr/share/icons/hicolor/scalable/apps /usr/share/polkit-1/actions
find /tmp/legion -name "*.desktop" -exec cp {} /usr/share/applications/ \;
find /tmp/legion -name "*.svg" -o -name "*.png" -exec cp {} /usr/share/icons/hicolor/scalable/apps/ \;
find /tmp/legion -name "*.policy" -exec cp {} /usr/share/polkit-1/actions/ \;

# Setup passwordless polkit rule for all legion actions
mkdir -p /usr/share/polkit-1/rules.d
cat << 'EOF' > /usr/share/polkit-1/rules.d/99-lenovo-legion-gui.rules
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("legion") !== -1 && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# --- STAGE C: PLASMAVANTAGE ---
git clone https://gitlab.com/Scias/plasmavantage.git /tmp/plasmavantage

# Install widget
mkdir -p /usr/share/plasma/plasmoids/com.gitlab.scias.plasmavantage
cp -r /tmp/plasmavantage/package/* /usr/share/plasma/plasmoids/com.gitlab.scias.plasmavantage/

mkdir -p /usr/lib/systemd/system/
cp /tmp/files/usr/lib/systemd/system/plasmavantage-noroot.service /usr/lib/systemd/system/

# --- STAGE D: CLEANUP ---
rm -rf /tmp/legion /tmp/plasmavantage
