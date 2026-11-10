#!/usr/bin/env bash
set -eo pipefail

command -v docker >/dev/null || { echo "docker is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
command -v du >/dev/null || { echo "du is required" >&2; exit 1; }

# Ignore whole mounts. Use host sources, container destinations, or both.
# This way we only have to usage of the container itself, not the data.
IGNORE_MOUNTS=(
    "/mnt/data/movies"
    "/mnt/data/documents"
    "/mnt/data/Data"
    "/mnt/data/Films"
    "/mnt/data/Z"
    "/media"                # Jellyfin
    "/mnt/data"             # samba
)

BACKUP_FOLDER="/mnt/data/salad-server/"

is_ignored_mount() {
    local source="$1" destination="$2" ignored

    for ignored in "${IGNORE_MOUNTS[@]}"; do
        if [[ "$source" == "$ignored" || "$source" == "$ignored/"* ||
              "$destination" == "$ignored" || "$destination" == "$ignored/"* ]]; then
            return 0
        fi
    done
    return 1
}

rows=()

while IFS= read -r container_id; do
    [[ -n "$container_id" ]] || continue

    container_json=$(docker inspect --type container "$container_id")

    stack_name=$(jq -r '
    .[0].Config.Labels["com.docker.stack.namespace"]
    // .[0].Config.Labels["com.docker.compose.project"]
    // empty
    ' <<< "$container_json")

    last_backup=""

    if [[ -n "$stack_name" && -d "$BACKUP_FOLDER/$stack_name" ]]; then
        backup_file=$(
            find "$BACKUP_FOLDER/$stack_name" -maxdepth 1 -type f \
                -name "${stack_name}_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9].tgz" \
                -printf '%f\n' 2>/dev/null |
            LC_ALL=C sort |
            tail -n 1
        )

        if [[ -n "$backup_file" ]]; then
            stamp=${backup_file#"${stack_name}_"}
            stamp=${stamp%.tgz}

            backup_date=${stamp%%_*}
            backup_time=${stamp#*_}
            backup_time=${backup_time//-/:}

            last_backup="${backup_date} ${backup_time}.000"
        fi
    fi

    name=$(jq -r '.[0].Name | ltrimstr("/")' <<< "$container_json")
    image_id=$(jq -r '.[0].Image' <<< "$container_json")
    image_name=$(jq -r '.[0].Config.Image' <<< "$container_json")

    created_raw=$(docker image inspect --format '{{.Created}}' \
        "$image_id" 2>/dev/null || true)

    if [[ -n "$created_raw" ]]; then
        creation_date=$(date -u -d "$created_raw" '+%Y-%m-%d %H:%M:%S.%3N')
    else
        creation_date=""
    fi

    disk_usage=0
    declare -A seen_sources=()

    while IFS=$'\t' read -r source destination; do
        [[ -n "$source" ]] || continue
        is_ignored_mount "$source" "$destination" && continue

        # Don't count the same host source twice for one container.
        [[ -n "${seen_sources[$source]+x}" ]] && continue
        seen_sources["$source"]=1

        [[ -e "$source" ]] || continue

        if du_line=$(du -s -B1 -- "$source" 2>/dev/null); then
            usage=${du_line%%$'\t'*}
            if [[ "$usage" =~ ^[0-9]+$ ]]; then
                disk_usage=$((disk_usage + usage))
            fi
        fi
    done < <(
        jq -r '.[0].Mounts[]?
            | select(.Type == "bind" or .Type == "volume")
            | [(.Source // ""), (.Destination // "")]
            | @tsv' <<< "$container_json" |
        sort -u
    )

    rows+=("$(jq -n \
        --arg id "$container_id" \
        --arg name "$name" \
        --arg image_id "$image_id" \
        --arg image_name "$image_name" \
        --arg creation_date "$creation_date" \
        --argjson disk_usage "$disk_usage" \
        --arg stack_name "$stack_name" \
        --arg last_backup "$last_backup" \
        '{($id): {
            name: $name,
            image: {
                id: $image_id,
                name: $image_name,
                creation_date: $creation_date
            },
            disk_usage: $disk_usage,
            stack_name: (if $stack_name == "" then null else $stack_name end),
            last_backup: (if $last_backup == "" then null else $last_backup end)
        }}')")
done < <(docker ps -aq --no-trunc)

if ((${#rows[@]})); then
    printf '%s\n' "${rows[@]}" | jq -s 'add'
else
    printf '{}\n'
fi
