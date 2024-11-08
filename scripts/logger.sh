#!/bin/bash

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

NAME=$1     # Name of the log file.
MESSAGE=$2  # Log entry.
LOGLEVEL=$3 # TRACE INFO WARN ERROR





################################################################################
# Constants
################################################################################

LOG_DIR="/var/log/salad"
LOG_FILE="${LOG_DIR}/${NAME}.log"





################################################################################
# Main
################################################################################

mkdir -p $LOG_DIR
timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# Console transport.
echo -e "[${timestamp} ${LOGLEVEL}]\t${MESSAGE}"

# File transport.
echo -e "[${timestamp} ${LOGLEVEL}]\t${MESSAGE}" >> $LOG_FILE
