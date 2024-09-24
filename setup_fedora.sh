#!/bin/bash

# Function to set DNF configuration
set_dnf_config() {
    echo -e "[main]\nmax_parallel_downloads=1\nfastestmirror=True" | sudo tee /etc/dnf/dnf.conf > /dev/null
}

# Configure DNF settings
set_dnf_config

# Install ptyxis-agent and set default browser
if ! command -v ptyxis-agent &> /dev/null; then
    sudo dnf install -y ptyxis-agent
    xdg-settings set default-web-browser ptyxis-agent.desktop
else
    echo "ptyxis-agent is already installed."
fi

# Clone Neofetch if it doesn't exist
if [ ! -d "neofetch" ]; then
    git clone https://github.com/dylanaraps/neofetch.git
    cd neofetch || exit
    sudo cp neofetch /usr/local/bin
    cd .. # Go back to the previous directory
else
    echo "Neofetch directory already exists. Skipping cloning."
fi

# Update system
sudo dnf update -y
sudo fwupdmgr refresh --force
sudo fwupdmgr get-updates
sudo fwupdmgr update

# Install additional packages
sudo dnf install -y dnf5 dnf5-plugins
if ! rpm -qa | grep -q rpmfusion-free-release; then
    sudo dnf install -y "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
fi
if ! rpm -qa | grep -q rpmfusion-nonfree-release; then
    sudo dnf install -y "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi
sudo dnf upgrade --refresh -y

# Enable preload and install it
if ! command -v preload &> /dev/null; then
    sudo dnf copr enable elxreno/preload -y
    sudo dnf install -y preload
else
    echo "Preload is already installed."
fi

# Install gnome-tweaks and other packages
if ! command -v gnome-tweaks &> /dev/null; then
    sudo dnf5 install -y gnome-tweaks
else
    echo "Gnome Tweaks is already installed."
fi

if ! flatpak list | grep -q com.mattjakeman.ExtensionManager; then
    flatpak install flathub com.mattjakeman.ExtensionManager -y
else
    echo "Extension Manager is already installed."
fi

if ! command -v timeshift &> /dev/null; then
    sudo dnf5 install -y timeshift
else
    echo "Timeshift is already installed."
fi

# Check and install fonts if not already installed
fonts=("dejavu-sans-fonts" "dejavu-serif-fonts" "dejavu-sans-mono-fonts" \
       "liberation-sans-fonts" "liberation-serif-fonts" "liberation-mono-fonts" \
       "google-noto-sans-fonts" "google-noto-serif-fonts" "google-noto-mono-fonts")

for font in "${fonts[@]}"; do
    if ! rpm -qa | grep -q "$font"; then
        sudo dnf install -y "$font"
    else
        echo "$font is already installed."
    fi
done

# Create Templates directory and file if they don't exist
if [ ! -d "~/Templates" ]; then
    mkdir -p ~/Templates
    touch ~/Templates/Blank\ Document.txt
else
    echo "Templates directory already exists."
fi

# Install corectrl
if ! command -v corectrl &> /dev/null; then
    sudo dnf install -y corectrl
    cp /usr/share/applications/org.corectrl.CoreCtrl.desktop ~/.config/autostart/org.corectrl.CoreCtrl.desktop
else
    echo "Corectrl is already installed."
fi

# Polkit permissions
pkaction --version
POLKIT_VERSION=$(pkaction --version | awk '{print $NF}')
if (( $(echo "$POLKIT_VERSION < 0.106" | bc -l) )); then
    echo -e "[User permissions]\nIdentity=unix-group:rico\nAction=org.corectrl.*\nResultActive=yes" | sudo tee /etc/polkit-1/localauthority/50-local.d/90-corectrl.pkla
else
    echo "polkit.addRule(function(action, subject) {
        if ((action.id == \"org.corectrl.helper.init\" ||
             action.id == \"org.corectrl.helperkiller.init\") &&
            subject.local == true &&
            subject.active == true &&
            subject.isInGroup(\"rico\")) {
            return polkit.Result.YES;
        }
    });" | sudo tee /etc/polkit-1/rules.d/90-corectrl.rules
fi

# Update GRUB if not already set
if ! grep -q "amdgpu.ppfeaturemask" /etc/default/grub; then
    sudo bash -c 'echo -e "GRUB_CMDLINE_LINUX=\"rhgb quiet amdgpu.ppfeaturemask=0xffffffff\"" >> /etc/default/grub'
else
    echo "GRUB_CMDLINE_LINUX is already set."
fi

echo "Setup completed!"

