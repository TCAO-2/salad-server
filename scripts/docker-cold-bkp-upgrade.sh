#!/bin/bash

# Stops a Docker stack for a cold backup,then restarts it with the latest version.

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

STACK_NAME=$1 # Same name as the sub-directory in /opt/salad-server/docker





################################################################################
# Constants
################################################################################

TMP_DIR="/tmp/salad-server.${STACK_NAME}"
BKP_DIR="/mnt/md0p1/backup/${STACK_NAME}"
BKP_NAME="${STACK_NAME}.$(date "+%Y-%m-%d-%H-%M-%S")"





################################################################################
# Main
################################################################################

cd "/opt/salad-server/docker/${STACK_NAME}"

# Check for newer images, if available, pull it first
# before stopping the stack to reduce the downtime.
docker compose pull

# Stop the stack.
docker compose down

# Copy the persistent data to a temporary directory
# in the SSD for further archiving, this is reducing the service downtime
# comparing to archiving directly to the RAID of HDD.
mkdir $TMP_DIR
cp -a . $TMP_DIR

# Start the stack.
docker compose up -d

# Archive the backup, then remove the temporary data.
mkdir -p ${BKP_DIR}
tar -czf "${BKP_DIR}/${BKP_NAME}.tar.gz" -C $TMP_DIR *
rm -rf $TMP_DIR
