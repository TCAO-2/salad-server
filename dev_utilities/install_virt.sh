#!/bin/bash

# Stop the script on error.
#set -e

# Script used from a Debian based distro.

sudo apt update -y
sudo apt upgrade -y

sudo apt install qemu qemu-kvm virt-manager bridge-utils -y
sudo groupadd libvirt
sudo usermod -a -G libvirt $USER
sudo groupadd libvirt-kvm
sudo usermod -a -G libvirt-kvm $USER
sudo systemctl enable libvirtd.service
sudo systemctl start libvirtd.service

# Relog yourself at this point to be able to use virt-manager.

# From virt-manager
# local install media -> provide Debian ISO
# fit real world home server configuration 16Gio (16384) RAM / 4 CPUs
# create a 64Gio main partition for tests in a custom storage
# keep default network settings for the installation (NAT virtual device, DHCP config)
# Create a regular user called "noroot"
# Do not encrypt the system, guided partitioning, separated /home /var and /tmp partitions
# Keep only standard system utilities
