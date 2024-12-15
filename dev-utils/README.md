# Directory overview

| Name         | Description                                          |
|--------------|------------------------------------------------------|
| install-virt | QEMU-KVM installation script for Debian based distro |

# Develop using a virtual machine

## Disclamer

I used the wifi interface for the host and the ethernet interface for the guest (passthrough).
You could setup a bridge network if you want to use only one interface.

## Guest setup

- run _install-virt.sh_ installation script
- open _virt-manager_
- edit > preferences > enable XML editing
- create a new VM -> local install media -> provide Debian ISO
- 16GiB (16384) RAM / 2 CPUs
- 64GiB disk
- customize configuration before install
- edit the network interface XML and change _interface_ to type="direct" and _source_ to dev="\<interface\>"
  ```XML
  <interface type="direct">
    <source dev="enp3s0"/>
    <mac address="52:54:00:88:57:2c"/>
    <model type="virtio"/>
  </interface>
  ```
- add 4 more disks of 16GiB
- begin installation


## Next

Follow install/README.md instructions as for a real server install.
