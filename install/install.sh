#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

IP_INTERFACE=enp1s0       # Check interfaces command: ip addr
IP_ADDRESS=192.168.0.110
IP_NETMASK=255.255.255.0
IP_GATEWAY=192.168.0.254
SSHD_PORT=22





################################################################################
# Install dependencies
################################################################################

packages=(
  "mlocate htop jq"         # Common tools.
  mdadm                     # Software RAID.
  hdparm                    # HDD sleep.
  unattended-upgrades       # Host auto upgrades.
  apt-config-auto-update    # Host auto reboot when required after upgrades.
  xxhash                    # Non-cryptographic fast hash for data integrity check.
  smartmontools             # Disks monitoring.
  swaks                     # Email alerting.
)
apt-get update -y
apt-get install -y ${packages[@]}





################################################################################
# Install Docker (from https://docs.docker.com/engine/install/debian/)
################################################################################

# Add Docker's official GPG key.
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources.
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y

# Install the Docker packages.
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin





################################################################################
# Configure SSHD
################################################################################

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i "s/^.PasswordAuthentication.*$/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i "s/^.PermitRootLogin.*$/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i "s/^.Port.*$/Port ${SSHD_PORT}/" /etc/ssh/sshd_config

systemctl restart sshd





################################################################################
# Configure unattended-upgrades
################################################################################

function active_unattended_cfg {
    sed -i "s/^.*Unattended-Upgrade::${1} .*;$/Unattended-Upgrade::${1} \"${2}\";/" \
    /etc/apt/apt.conf.d/50unattended-upgrades
}

# Remove unused automatically installed kernel-related packages.
active_unattended_cfg "Remove-Unused-Kernel-Packages" "true"

# Do automatic removal of newly unused dependencies after the upgrade.
active_unattended_cfg "Remove-New-Unused-Dependencies" "true"

# Do automatic removal of unused packages after the upgrade.
active_unattended_cfg "Remove-Unused-Dependencies" "true"

# Automatically reboot *WITHOUT CONFIRMATION* if
# the file /var/run/reboot-required is found after the upgrade.
active_unattended_cfg "Automatic-Reboot" "true"

# If automatic reboot is enabled and needed, reboot at the specific
# time instead of immediately.
active_unattended_cfg "Automatic-Reboot-Time" "04:00"

# Schedule upgrades on 03:30 everyday.
echo "30 03 * * * /usr/bin/unattended-upgrade" | crontab -





################################################################################
# Improve the root shell
################################################################################

# Add sbin to root user $PATH
echo 'PATH="/sbin:$PATH"' >> /root/.bashrc

# Add color to ls
echo "
export LS_OPTIONS='--color=auto'
eval \"\$(dircolors)\"
alias ls='ls \$LS_OPTIONS'
" >> /root/.bashrc





################################################################################
# Lock noroot actions
################################################################################

# Do not allow the noroot user to go to /opt or /mnt
# where the whole server data will be.
chmod o-x /opt /mnt





################################################################################
# Configure the logger
################################################################################

mkdir /var/log/salad

# logrotate configuration file.
echo '/var/log/salad/*.log {
    rotate 7
    daily
    notifempty
}' > /etc/logrotate.d/salad





################################################################################
# Configure static IP
################################################################################

cp /etc/network/interfaces /etc/network/interfaces.bak

echo "\
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug ${IP_INTERFACE}
iface ${IP_INTERFACE} inet static
address ${IP_ADDRESS}
netmask ${IP_NETMASK}
gateway ${IP_GATEWAY}
" > /etc/network/interfaces

echo "You are about to likely loose the SSH connection, reconnect with:"
echo "ssh noroot@${IP_ADDRESS}"
systemctl restart networking
