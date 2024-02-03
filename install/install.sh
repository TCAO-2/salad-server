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
CORE_ADMIN_USR="noroot" # The main admin user, will have sudo privileges.
CORE_ADMIN_USR_PASSWORD="password"
CORE_IP="192.168.122.59/24" # The static IP you want for the server.

# ssh
SSH_AllowUsers="bastion" # Allowed to login through SSH and to switch user.
SSH_Match_Address="0.0.0.0/0" # Attack surface reduction, range or single IP.
SSH_Port="22"
SSH_PasswordAuthentication="no" # If "no", ./ssh/authorized_keys required.





###############################################################################
# Common functions
###############################################################################

BLUE="\033[0;34m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

function log_trace  { echo -e "${BLUE}[TRACE ${FUNCNAME[1]}] ${1}${NC}"; }
function log_info  { echo -e "${GREEN}[INFO  ${FUNCNAME[1]}] ${1}${NC}"; }
function log_warn { echo -e "${YELLOW}[WARN  ${FUNCNAME[1]}] ${1}${NC}"; }
function log_err { echo -e "${RED}[ERR   ${FUNCNAME[1]}] ${1}${NC}"; return 1; }

function is_service_ok {
    systemctl status $1 | grep -E "Loaded: loaded" && \
    systemctl status $1 | grep -E "Active: active \(running\)"
}

function install_component {
    # $1 component_name
    if ${1}_install_ok &> /dev/null; then
        log_info "${1} component already installed."
    else
        log_trace "Executing ${1} component install..."
        ${1}_install
        if ${1}_install_ok &> /dev/null; then
            log_info "${1} component installation success."
        else
            log_err "${1} component installation failed."
        fi
    fi
}





###############################################################################
# Component core functions
###############################################################################

function core_apt_install {
    log_trace "Update packages..."
    apt-get update -y && apt upgrade -y

    log_trace "Install vim git mlocate htop packages..."
    apt-get install -y vim git mlocate htop
}

function core_apt_install_ok {
    vim --version && \
    git --version && \
    locate --version && \
    htop --version
}

function core_admin_usr_install {
    log_trace "Create ${CORE_ADMIN_USR} if not exists..."
    if ! id -u $CORE_ADMIN_USR &>/dev/null; then
        useradd $CORE_ADMIN_USR -m -s /bin/bash
        log_trace "Setup default password for ${CORE_ADMIN_USR}..."
        echo $CORE_ADMIN_USR:$CORE_ADMIN_USR_PASSWORD | chpasswd
    fi

    log_trace "Set the ${CORE_ADMIN_USR} as a sudo one..."
    usermod -aG sudo $CORE_ADMIN_USR
}

function core_admin_usr_install_ok {
    grep "^sudo:.*${CORE_ADMIN_USR}" /etc/group
}

function core_install {
    install_component core_apt
    install_component core_admin_usr
}

function core_install_ok {
    core_apt_install_ok && \
    core_admin_usr_install_ok
}





###############################################################################
# Component ssh functions
###############################################################################

function ssh_install {
    log_trace "Update packages..."
    sudo apt-get update -y && sudo apt upgrade -y

    log_trace "Install fail2ban..."
    sudo apt-get install -y fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
}

function ssh_install_ok {
    is_service_ok fail2ban
}





###############################################################################
# Main execution
###############################################################################

if [[ $(whoami) = "root" ]]; then
    log_info "Executed as root, install only core dependencies..."
    install_component core
    log_warn "To continue, execute the script as the ${CORE_ADMIN_USR} user."
else
    if core_install_ok > /dev/null; then
        for component in ${SELECTED_COMPONENTS[@]}; do
            install_component ${component}
        done
    else
        log_err "The script must be executed as the root user first."
    fi
fi
