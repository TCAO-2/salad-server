# System installation from the Debian ISO

- create a regular user called _noroot_
- manual partitioning on the OS drive,
here is a sample configuration for a 256GB drive, your needs may vary:
  ```
  swap  logical 8GiB
  /opt  logical 16GiB
  /var  logical 16GiB
  /tmp  logical 16GiB
  /home logical 16GiB
  /     primary max
  ```
- choose a mirror for aptitude
- software selection:
  - no desktop environment
  - SSH server
  - standard system utilities

# Add noroot SSH access using the public key from your PC

```bash
# If you don't have already a SSH key pair, generate it.
ssh-keygen
# Add your SSH public key into noroot authorized_keys file.
ssh-copy-id -i ~/.ssh/id_ed25519.pub noroot@<server ip>
```

# Connect to the server

The _noroot_ user will only be used for SSH and SFTP access.
You must then switch to the _root_ user for anything else once connected.

```bash
# Connect to the server using SSH.
ssh noroot@<server ip>
# Switch to the root user.
su root
```

# Installation, as root

## Core install

```bash
# Install dependencies.
apt-get update
apt-get install git vim

# Clone the git repository.
cd /opt
git clone https://github.com/TCAO-2/salad-server.git
cd salad-server/install

# Edit the installation script parameters.
vim install.sh

# Execute the installation script.
./install.sh
```

## Optional install, data RAID

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
