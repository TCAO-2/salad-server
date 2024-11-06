#!/bin/bash

# Upgrade a Docker stack to the latest version with minimun downtime.

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

STACK_NAME=$1 # Same name as the sub-directory in /opt/salad-server/docker





################################################################################
# Main
################################################################################

cd "/opt/salad-server/docker/${STACK_NAME}"

# # Check for newer images.
docker compose pull

# Upgrade the stack.
docker compose up -d
