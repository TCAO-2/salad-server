#!/bin/bash

# Keep the x most recent files.
# Backups must be named NAME_YYYY-MM-DD_hh-mm-ss.tgz so we can use name order.

# Stop the script on error.
set -e

BACKUP_NAME=""
LOGFILE_NAME="bkp-simple-rotate"

function logger {
    local message=$1
    local loglevel=$2
    local filename=$BACKUP_NAME
    if [ -z "${filename}" ]; then
        /opt/salad-server/scripts/logger.sh "$LOGFILE_NAME" "$message" "$loglevel" \
        || echo "[${loglevel}] ${message}"
    else
        /opt/salad-server/scripts/logger.sh "${LOGFILE_NAME}/${filename}" "$message" "$loglevel" \
        || echo "[${loglevel}] ${message}"
    fi
}

trap 'logger "Unexpected error at line ${LINENO}: \"${BASH_COMMAND}\" returns ${?}." "ERROR"' ERR

function show_help() {
    echo "Usage:"
    echo "  ./bkp-simple-rotate [-h] <str>"
    echo "Examples:"
    echo "  ./bkp-simple-rotate caddy"
    echo "Mandatory:"
    echo "  <str> Backup name (folder name in /mnt/data/salad-server/)"
    echo "Options:"
    echo "  -h, --help                Display this help message."
}





################################################################################
# Parameters
################################################################################

if [ "$#" -eq 0 ]; then
    logger "Missing argument." "ERROR"
    show_help
    exit 1
fi

BACKUP_NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ "$BACKUP_NAME" == "" ]; then
                BACKUP_NAME="$1"
            else
                logger "Too many arguments." "ERROR"
                show_help
                exit 1
            fi
            ;;
    esac
    shift
done

if [ "$BACKUP_NAME" == "" ]; then
    logger "Missing argument." "ERROR"
    show_help
    exit 1
fi





################################################################################
# Constants
################################################################################

BKP_DIR="/mnt/data/salad-server/${BACKUP_NAME}"
BKP_TOO_KEEP=10





################################################################################
# Main execution
################################################################################

if [ ! -d "${BKP_DIR}" ]; then
  logger "${BKP_DIR} does not exist." "ERROR"
  exit 1
fi

cd "${BKP_DIR}"

bkp_number=1
for filename in $(ls | sort -r); do
    if [ $bkp_number -gt $BKP_TOO_KEEP ]; then
        logger "Deleting ${BKP_DIR}/${filename} ..." "VERB"
        rm ${BKP_DIR}/${filename}
        logger "${BKP_DIR}/${filename} deleted." "INFO"
    else
        logger "Keeping ${BKP_DIR}/${filename} ." "VERB"
    fi
    bkp_number=$((bkp_number+1))
done
