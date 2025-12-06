#!/bin/bash

# Stops a Docker stack for a cold backup,then restarts it with the latest version.
# We are expecting that the Docker images, the tmp dir and the bkp dir
# are different file systems in the space left estimation.

# Stop the script on error.
set -e





################################################################################
# Parameters
################################################################################

STACK_NAME=$1 # Same name as the sub-directory in /opt/salad-server/docker





################################################################################
# Constants
################################################################################

TIMESTAMP=$(date "+%Y-%m-%d-%H-%M-%S")
SRC_DIR="/opt/salad-server/docker/${STACK_NAME}"
TMP_DIR="/tmp/salad-server"
BKP_DIR="/mnt/data/salad-server/${STACK_NAME}"
BKP_NAME="${STACK_NAME}_${TIMESTAMP}"
DOCKER_IMG_DIR="/var/lib/docker"





################################################################################
# Functions
################################################################################

function logger {
    message=$1
    loglevel=$2
    /opt/salad-server/scripts/logger.sh "docker-cold-bkp-upgrade" "$message" "$loglevel"
}

function get_docker_image_name_from_hash {
    hash=$1
    docker image ls --no-trunc | grep $hash | awk '{print $1}'
}

function check_space_left {
    path=$1
    required_space=$2
    available_space=$(df --output=avail -B1 "${path}" | awk 'NR==2')
    if (( available_space >= required_space )); then
        logger "Enough available space in ${path}: ${required_space}/${available_space}" "TRACE"
    else
        logger "Not enough available space in ${path}: ${required_space}/${available_space}" "ERROR"
        exit 11
    fi
}





################################################################################
# Init
################################################################################

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

# Current Docker images backup.
mkdir -p "${TMP_DIR}/${BKP_NAME}"
for image_id in $(echo $current_images | jq -r '.[].ID');do
    image_name="$(get_docker_image_name_from_hash $image_id)_${image_id:7:12}"
    normalized_image_name=$(echo $image_name | sed -r 's/\//_/g')
    destination_tar="${TMP_DIR}/${BKP_NAME}/docker_img_${normalized_image_name}.tar"
    logger "Saving Docker image ${image_name} -> ${destination_tar} ..." "VERB"
    docker save $image_id > ${destination_tar}
done

logger "Pull newer images if available upgrade..." "VERB"
docker compose pull

start_time=$(date +%s)

logger "Stopping the stack..." "VERB"
docker compose down

logger "Copying ${SRC_DIR} -> ${TMP_DIR}/${BKP_NAME}/data.tar ..." "VERB"
tar -cf "${TMP_DIR}/${BKP_NAME}/data.tar" -C "${SRC_DIR}" .

logger "Starting the stack..." "VERB"
docker compose up -d

end_time=$(date +%s)
delta_time=$(($end_time - $start_time))

# INFO overview log.
upgraded_images=$(docker compose images --format json)
for current_image in $(echo $current_images | jq -c '.[]'); do
    current_id=$(echo $current_image | jq -r '.ID')
    current_repository=$(echo $current_image | jq -r '.Repository')
    for upgraded_image in $(echo $upgraded_images | jq -c '.[]'); do
        upgraded_id=$(echo $upgraded_image | jq -r '.ID')
        upgraded_repository=$(echo $upgraded_image | jq -r '.Repository')
        if [ "$current_repository" = "$upgraded_repository" ]; then
            if [ "$current_id" = "$upgraded_id" ]; then
                logger "$current_repository restarted using same version ${current_id:7:12} (downtime ${delta_time}s)." "INFO"
            else
                logger "$current_repository restarted after upgrade ${current_id:7:12} -> ${upgraded_id:7:12} (downtime ${delta_time}s)." "INFO"
            fi
        fi
    done
done

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
