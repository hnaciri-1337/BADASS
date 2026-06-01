#!/bin/bash
echo "--------------------------------------------------"
echo "Running install.sh - System setup in progress..."
echo "--------------------------------------------------"

# Update and install dependencies
apt update
apt install -y software-properties-common

echo "--------------------------------------------------"
echo "Installing GNS3"
echo "--------------------------------------------------"

# Add GNS3 Repository
add-apt-repository -y ppa:gns3/ppa
apt update
apt install -y gns3-gui gns3-server
wget -qO- https://raw.githubusercontent.com/GNS3/gns3-webclient-pack/master/install.sh | sh

echo "--------------------------------------------------"
echo "Installing Docker"
echo "--------------------------------------------------"

# Add Docker's official GPG key
apt update
apt install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "--------------------------------------------------"
echo "Adding Docker repository"
echo "--------------------------------------------------"

# Add Docker repository to Apt sources
tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt update

# Install Docker
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to required groups
usermod -aG ubridge,libvirt,kvm,wireshark,docker vagrant

echo "--------------------------------------------------"
echo "Setup complete!"
echo "--------------------------------------------------"