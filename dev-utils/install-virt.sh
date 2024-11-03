#!/bin/bash

# Stop the script on error.
set -e

sudo apt-get update -y
sudo apt-get install -y qemu qemu-kvm virt-manager

sudo groupadd libvirt
sudo usermod -a -G libvirt $USER
sudo groupadd libvirt-kvm
sudo usermod -a -G libvirt-kvm $USER

sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

YELLOW="\033[1;33m"
NC="\033[0m"
echo -e "${YELLOW}Relog yourself at this point to be able to use virt-manager${NC}"
