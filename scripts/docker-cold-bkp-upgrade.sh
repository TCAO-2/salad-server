#!/bin/bash

# Stops a Docker stack for a cold backup,then restarts it with the latest version.
# We are expecting that the Docker images, the tmp dir and the bkp dir
# are different file systems in the space left estimation.

# Stop the script on error.
set -e

STACK_NAME=""
LOGFILE_NAME="docker-cold-bkp-upgrade"

function logger {
    local message=$1
    local loglevel=$2
    local filename=$STACK_NAME
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
    echo "  ./docker-cold-bkp-upgrade [-h] [-u] <str>"
    echo "Examples:"
    echo "  ./docker-cold-bkp-upgrade -u caddy"
    echo "  ./docker-cold-bkp-upgrade minecraft"
    echo "Mandatory:"
    echo "  <str> Stack name (folder name in /opt/salad-server/docker/)"
    echo "Options:"
    echo "  -h, --help                Display this help message."
    echo "  -u, --only-on-upgrade     Do not do anything if no upgrade is available."
}





################################################################################
# Parameters
################################################################################

if [ "$#" -eq 0 ]; then
    logger "Missing argument." "ERROR"
    show_help
    exit 1
fi

ONLY_ON_UPGRADE=1
STACK_NAME=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -u|--only-on-upgrade)
            ONLY_ON_UPGRADE=0
            ;;
        *)
            if [ "$STACK_NAME" == "" ]; then
                STACK_NAME="$1"
            else
                logger "Too many arguments." "ERROR"
                show_help
                exit 1
            fi
            ;;
    esac
    shift
done

if [ "$STACK_NAME" == "" ]; then
    logger "Missing argument." "ERROR"
    show_help
    exit 1
fi





################################################################################
# Constants
################################################################################

TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
SRC_DIR="/opt/salad-server/docker/${STACK_NAME}"
TMP_DIR="/tmp/salad-server"
BKP_DIR="/mnt/data/salad-server/${STACK_NAME}"
BKP_NAME="${STACK_NAME}_${TIMESTAMP}"
DOCKER_IMG_DIR="/var/lib/docker"
TIMEOUT_HEALTHCHECK=120





################################################################################
# Functions
################################################################################

function get_docker_image_name_from_hash {
    local hash=$1
    docker image ls --no-trunc | grep $hash | awk '{print $1}'
}

function check_space_left {
    local path=$1
    local required_space=$2
    local available_space=$(df --output=avail -B1 "${path}" | awk 'NR==2')
    if (( available_space >= required_space )); then
        logger "Enough available space in ${path}: ${required_space}/${available_space}" "TRACE"
    else
        logger "Not enough available space in ${path}: ${required_space}/${available_space}" "ERROR"
        exit 11
    fi
}

function is_unhealthy_container_in_stack {
    # Containers without healthcheck are considered healthy as long as they are running.
    local containers_not_running=$(docker compose ps --format '{{.State}}' \
        | grep -iE "created|paused|restarting|exited|removing|dead")
    local containers_unhealthy=$(docker compose ps --format '{{.Status}}' \
        | grep -iE "starting|unhealthy")
    if [[ -z "$containers_not_running" ]] && [[ -z "$containers_unhealthy" ]]; then
        return 1
    else
        return 0
    fi
}

function wait_until_the_stack_is_healthy {
    local time_elapsed=0
    while is_unhealthy_container_in_stack; do
        sleep 1
        time_elapsed=$((time_elapsed+1))
        if [ $time_elapsed -gt $TIMEOUT_HEALTHCHECK ]; then
            logger "${STACK_NAME} stack restart timed out after ${TIMEOUT_HEALTHCHECK}s." "ERROR"
            return 0
        fi
    done
}

function log_restarted_stack {
    local _current_images=$1
    local _start_time=$2
    local end_time=$(date +%s)
    local delta_time=$(($end_time - $_start_time))
    local upgraded_images=$(docker compose images --format json)
    for current_image in $(echo $_current_images | jq -c '.[]'); do
        local current_id=$(echo $current_image | jq -r '.ID')
        local current_repository=$(echo $current_image | jq -r '.Repository')
        for upgraded_image in $(echo $upgraded_images | jq -c '.[]'); do
            local upgraded_id=$(echo $upgraded_image | jq -r '.ID')
            local upgraded_repository=$(echo $upgraded_image | jq -r '.Repository')
            if [ "$current_repository" = "$upgraded_repository" ]; then
                if [ "$current_id" = "$upgraded_id" ]; then
                    logger "$current_repository restarted using same version ${current_id:7:12} (downtime ${delta_time}s)." "INFO"
                else
                    logger "$current_repository restarted after upgrade ${current_id:7:12} -> ${upgraded_id:7:12} (downtime ${delta_time}s)." "INFO"
                fi
            fi
        done
    done
}





################################################################################
# Init
################################################################################

echo $SRC_DIR

if [ ! -d "${SRC_DIR}" ]; then
  logger "${SRC_DIR} does not exist." "ERROR"
  exit 1
fi

cd "${SRC_DIR}"

current_containers_count=$(docker compose ps -a --format '{{.ID}}' | wc -l)
if (( current_containers_count == 0 )); then
    logger "The Docker stack is not running, nothing to backup or upgrade." "ERROR"
    exit 1
fi

current_images=$(docker compose images --format json)

mkdir -p "${TMP_DIR}"
mkdir -p "${BKP_DIR}"

# Check if there is enough space left for upgrade and backup.

images_size=0
for image_size in $(echo $current_images | jq '.[].Size');do
    images_size=$((data_size + image_size))
done
logger "Potential Docker images upgrade expected size: ${images_size}" "TRACE"

persistent_data_size=$(du -sb "${SRC_DIR}" | awk '{print $1}')
data_size=$((persistent_data_size + images_size))
logger "Full backup expected size: ${data_size}" "TRACE"

check_space_left "${DOCKER_IMG_DIR}" $images_size
check_space_left "${TMP_DIR}" $data_size
check_space_left "${BKP_DIR}" $data_size





################################################################################
# Main execution
################################################################################

docker_img_nb_before_pull=$(docker images -a -q | wc -l)
logger "Pull newer images if available upgrade..." "VERB"
docker compose pull
docker_img_nb_after_pull=$(docker images -a -q | wc -l)

if [ $ONLY_ON_UPGRADE -eq 0 ] && [ $docker_img_nb_before_pull -eq $docker_img_nb_after_pull ]; then
    logger "No upgrade available and --only-on-upgrade was passed." "INFO"
    exit 0
fi

# Current Docker images backup.
mkdir -p "${TMP_DIR}/${BKP_NAME}"
for image_id in $(echo $current_images | jq -r '.[].ID');do
    image_name="$(get_docker_image_name_from_hash $image_id)_${image_id:7:12}"
    normalized_image_name=$(echo $image_name | sed -r 's/\//_/g')
    destination_tar="${TMP_DIR}/${BKP_NAME}/docker_img_${normalized_image_name}.tar"
    logger "Saving Docker image ${image_name} -> ${destination_tar} ..." "VERB"
    docker save $image_id > ${destination_tar}
done

start_time=$(date +%s)

logger "Stopping the stack..." "VERB"
docker compose down

logger "Copying ${SRC_DIR} -> ${TMP_DIR}/${BKP_NAME}/data.tar ..." "VERB"
tar -cf "${TMP_DIR}/${BKP_NAME}/data.tar" -C "${SRC_DIR}" .

logger "Starting the stack..." "VERB"
docker compose up -d

logger "Wait until the stack is healthy..." "VERB"
wait_until_the_stack_is_healthy
log_restarted_stack $current_images $start_time

logger "Archiving ${TMP_DIR}/${BKP_NAME} -> ${BKP_DIR}/${BKP_NAME}.tgz ..." "VERB"
cd "${TMP_DIR}/${BKP_NAME}"
tar -czf "${BKP_DIR}/${BKP_NAME}.tgz" -C "${TMP_DIR}/${BKP_NAME}" .

bkp_size=$(stat -c %s ${BKP_DIR}/${BKP_NAME}.tgz | numfmt --to=iec)
logger "Backup archived ${BKP_DIR}/${BKP_NAME}.tgz (${bkp_size})." "INFO"

logger "Removing temporary data ${TMP_DIR}/${BKP_NAME} ..." "VERB"
cd "${SRC_DIR}"
rm -r "${TMP_DIR}/${BKP_NAME}"

logger "Removing unused Docker images..." "VERB"
docker image prune -af
