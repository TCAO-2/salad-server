#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

SSHD_PORT=22





################################################################################
# Install dependencies
################################################################################

apt-get update -y
apt-get install -y mlocate htop smartmontools mdadm
#iptables-persistent ntfs-3g hdparm





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
