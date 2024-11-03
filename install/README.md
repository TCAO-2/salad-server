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
vim install-raid.sh
# Setup a RAID5 array if you don't already have one
# (RAID5 array will be persistent across server re-installs).
./install-raid.sh
```
