#!/bin/bash

# Handle logging for multiple transports.
# You can export the min log level for each transport.
# You can also make these permanent using /etc/environment
#
#   | transport | min log level (default)  |
#   |-----------|--------------------------|
#   | console   | LOG_LEVEL_CONSOLE (INFO) |
#   | file      | LOG_LEVEL_FILE    (INFO) |
#
# Available log levels in severity order are TRACE VERB INFO WARN ERROR
#
# "file" transport logs into /var/log/salad files which are managed by logrotate.
# See "Configure the logger" section of the server installation script.

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

LOG_NAME=$1     # Name of the log entry (will be in the log file name).
LOG_MESSAGE=$2  # Log entry.
LOG_LEVEL=$3    # Log entry level.





################################################################################
# Constants
################################################################################

LOG_DIR="/var/log/salad"
LOG_FILE="${LOG_DIR}/${LOG_NAME}.log"

# Message colors.
declare -A LOG_LEVELS=(
    [TRACE]=0
    [VERB]=1
    [INFO]=2
    [WARN]=3
    [ERROR]=4
)
declare -A LOG_COLORS=(
    [TRACE]="\033[0;34m"    # BLUE
    [VERB]="\033[0;36m"     # CYAN
    [INFO]="\033[0;32m"     # GREEN
    [WARN]="\033[1;33m"     # YELLOW
    [ERROR]="\033[0;31m"    # RED
)
NC="\033[0m"                # NO COLOR

# Default minimum log levels depending on the transport.
if [ -z $LOG_LEVEL_CONSOLE ]; then
    LOG_LEVEL_CONSOLE="VERB"
fi
if [ -z $LOG_LEVEL_FILE ]; then
    LOG_LEVEL_FILE="TRACE"
fi





################################################################################
# Helper functions
################################################################################

function echo_console {
    local message="${1}"

    # Check if the log level is within the console display threshold
    if [[ ${LOG_LEVELS[$LOG_LEVEL]} -ge ${LOG_LEVELS[$LOG_LEVEL_CONSOLE]} ]]; then
        echo -e "${LOG_COLORS[$LOG_LEVEL]}${message}${NC}"
    fi
}

function echo_file {
    local message="${1}"

    # Check if the log level is within the console display threshold
    if [[ ${LOG_LEVELS[$LOG_LEVEL]} -ge ${LOG_LEVELS[$LOG_LEVEL_FILE]} ]]; then
        echo "${message}" >> $LOG_FILE
    fi
}





################################################################################
# Main
################################################################################

mkdir -p "${LOG_DIR}"
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Console transport.
echo_console "[${timestamp} ${LOG_LEVEL}]\t${LOG_MESSAGE}"

# File transport.
echo_file "[${timestamp} ${LOG_LEVEL}] ${LOG_MESSAGE}"
