# System installation from the Debian ISO

- create a regular user called _noroot_
- manual partitioning on the OS drive,
here is a sample configuration for a 256GB drive, your needs may vary:
  ```
  efi    efi     100MiB
  swap   swap    16GiB
  /opt   ext4    96GiB    # Docker services data
  /var   ext4    16GiB    # Logs
  /tmp   ext4    48GiB    # Docker services backup temporary directory
  /home  ext4    48GiB    # SFTP temporary directory
  /      ext4    max
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

## Optional install, existing data RAID

```bash
# Add the data mountpoint in /etc/fstab
(/etc/fstab)               UUID=$uuid /mnt/data ext4 defaults,noexec 0 2
# Add events alerts in /etc/mdadm/mdadm.conf
(/etc/mdadm/mdadm.conf)    PROGRAM /opt/salad-server/scripts/mdadm-event.sh
# Mount the array.
systemctl daemon-reload
mount /mnt/data
```

## Optional install, new data RAID

```bash
# Edit the installation script parameters.
cd /opt/salad-server/install
vim install-disk-raid.sh

# Setup a data RAID5 array if you don't already have one
# (RAID5 array will be persistent across server re-installs).
./install-disk-raid.sh
```

## Optional install, HDD sleep

```bash
# For each physical HDD.
hdparm --yes-i-know-what-i-am-doing -s 1 /dev/sdX
# Value provided must be in [1,255] and is 5x the seconds to wait before sleep.
# Here 120 corresponds to 10 minutes.
hdparm -S 120 /dev/sdX
# Add the standby in /etc/hdparm.conf file to make it persistent.
/dev/sdX {
    spindown_time = 120
}
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
