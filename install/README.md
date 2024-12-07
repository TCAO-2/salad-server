# From the server itself, as root

```bash
# Install dependencies.
apt-get update
apt-get install openssh-server git vim
```

# Add noroot SSH RSA public key from your PC

```bash
# If you don't have already a SSH RSA key pair, generate it using ssh-keygen
# Add your SSH RSA public key into noroot authorized_keys file.
ssh-copy-id -i ~/.ssh/id_rsa.pub noroot@<server ip>
```

# Using SSH, as root

```bash
# Clone the git repository.
cd /opt
git clone https://github.com/TCAO-2/salad-server.git
cd salad-server/install

# Edit the installation script parameters.
vim install.sh

# Execute the installation script.
./install.sh
```

# Optional install, as root

```bash
# Edit the installation script parameters.
cd /opt/salad-server/install
vim install-disk-raid.sh

# Setup a data RAID5 array if you don't already have one
# (RAID5 array will be persistent across server re-installs).
./install-disk-raid.sh
```

# Maintenance, as root

```bash
# Extend or repair the data RAID5 array.

# Check the array.
mdadm -D /dev/md0

# Add a disk to the array.
mdadm /dev/md0 --add /dev/vdX

# Because the disk hardware configuration have changed,
# you have to update disks routines.
cd /opt/salad-server/install
./update-disk-routines.sh
```
