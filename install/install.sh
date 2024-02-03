#!/bin/bash

# Install all selected components.

# Stop the script on error.
set -e





###############################################################################
# User editable parameters
###############################################################################

SELECTED_COMPONENTS=(
    "ssh"           # Remote SSH access.
)

# core
CORE_REGULAR_USR="noroot" # The main admin user, will have sudo privileges.

# ssh
SSH_AllowUsers="bastion" # Allowed to login through SSH and to switch user.
SSH_Match_Address="0.0.0.0/0" # Attack surface reduction, range or single IP.
SSH_Port="22"
SSH_PasswordAuthentication="no" # If "no", ./ssh/authorized_keys required.





###############################################################################
# Common functions
###############################################################################





###############################################################################
# Component core functions
###############################################################################

function core_install {
    # Common aptitude packages.
    apt update -y && apt upgrade -y
    apt install -y vim git mlocate htop

    # Set the $REGULAR_USR as a sudo one.
    usermod -aG sudo $REGULAR_USR
}

function core_install_ok {

}





###############################################################################
# Component ssh functions
###############################################################################

function ssh_install {

}

function ssh_install_ok {

}





###############################################################################
# Main execution
###############################################################################

for component in ${SELECTED_COMPONENTS[@]}; do
    echo $component
done
