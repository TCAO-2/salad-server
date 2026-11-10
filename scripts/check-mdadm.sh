#!/usr/bin/env bash
set -eo pipefail
export LC_ALL=C
shopt -s nullglob

CHECK_ACTIVITY=/opt/salad-server/scripts/check-disk-activity.sh
STANDBY_DELAY=600 # seconds

command -v mdadm >/dev/null || { echo "mdadm is required" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

# Read a labeled field from the current mdadm --detail output.
get_field() {
    local wanted="$1"

    awk -F ':' -v wanted="$wanted" '
        {
            label = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", label)

            if (label == wanted) {
                value = substr($0, index($0, ":") + 1)
                sub(/^[[:space:]]+/, "", value)
                sub(/[[:space:]]+$/, "", value)

                if (wanted == "Name")
                    sub(/[[:space:]]+\(local to host.*/, "", value)

                print value
                exit
            }
        }
    ' <<< "$detail"
}

get_number() {
    local value
    value=$(get_field "$1")

    awk -v value="$value" 'BEGIN {
        split(value, parts, /[[:space:]]+/)
        if (parts[1] ~ /^[0-9]+$/)
            print parts[1]
    }'
}

# Recursively follow stacked block devices to their leaf devices.
# If a leaf is a partition, check its whole parent disk instead.
collect_leaf_devices() {
    local name="$1"
    local sys="/sys/class/block/$name"
    local slave resolved leaf found=0

    [[ -e "$sys" ]] || return 1

    for slave in "$sys"/slaves/*; do
        [[ -e "$slave" ]] || {
            [[ -L "$slave" ]] && return 1
            continue
        }
        found=1
        collect_leaf_devices "${slave##*/}" || return 1
    done

    if (( found )); then
        return 0
    fi

    resolved=$(readlink -f -- "$sys") || return 1
    if [[ -r "$sys/partition" ]]; then
        leaf=$(basename -- "$(dirname -- "$resolved")")
    else
        leaf=$name
    fi

    [[ -b "/dev/$leaf" ]] || return 1
    printf '/dev/%s\n' "$leaf"
}

json_array() {
    if (($# == 0)); then
        printf '[]'
    else
        printf '%s\n' "$@" | jq -R . | jq -s .
    fi
}

rows=()

# Discover MD arrays through sysfs, so no mdadm command is needed for discovery.
for md_path in /sys/block/md*; do
    [[ -d "$md_path/md" ]] || continue

    md_name=${md_path##*/}
    array="/dev/$md_name"
    sleeping_devices=()
    check_errors=()
    declare -A seen_disks=()

    if [[ ! -b "$array" ]]; then
        check_errors+=("$array: block device node unavailable")
    fi

    member_links=("$md_path"/md/dev-*/block)
    if ((${#member_links[@]} == 0)); then
        check_errors+=("$md_name: no member devices found in sysfs")
    fi

    for member_link in "${member_links[@]}"; do
        if [[ ! -e "$member_link" ]]; then
            check_errors+=("$member_link: member device unavailable")
            continue
        fi

        member_sys=$(readlink -f -- "$member_link") || {
            check_errors+=("$member_link: cannot resolve member device")
            continue
        }
        member_name=${member_sys##*/}

        if ! leaf_text=$(collect_leaf_devices "$member_name"); then
            check_errors+=("$member_name: cannot resolve underlying disk")
            continue
        fi

        while IFS= read -r disk; do
            [[ -n "$disk" ]] || continue
            [[ ${seen_disks[$disk]+yes} ]] && continue
            seen_disks[$disk]=1

            if age=$("$CHECK_ACTIVITY" "$disk"); then
                if [[ ! "$age" =~ ^[0-9]+$ ]]; then
                    check_errors+=("$disk: activity checker returned a non-integer")
                elif (( age > STANDBY_DELAY )); then
                    sleeping_devices+=("$disk")
                fi
            else
                check_errors+=("$disk: activity check failed")
            fi
        done <<< "$leaf_text"
    done

    if ((${#sleeping_devices[@]})); then
        rows+=("$(jq -n --arg device "$array" \
            '{($device): {state: "standby"}}')")
        continue
    fi

    if ((${#check_errors[@]})); then
        printf 'Skipping %s: %s\n' "$array" "${check_errors[*]}" >&2
        rows+=("$(jq -n --arg device "$array" \
            '{($device): {state: "unknown"}}')")
        continue
    fi

    # This is the first mdadm invocation for this array; all its member
    # disks passed the activity check.
    if detail=$(mdadm --detail "$array" 2>/dev/null); then
        mdadm_return_code=0
    else
        mdadm_return_code=$?
        detail=""
    fi

    name=$(get_field "Name")
    raid_level=$(get_field "Raid Level")
    state=$(get_field "State")

    array_size=$(get_number "Array Size")
    raid_devices=$(get_number "Raid Devices")
    total_devices=$(get_number "Total Devices")
    active_devices=$(get_number "Active Devices")
    working_devices=$(get_number "Working Devices")
    failed_devices=$(get_number "Failed Devices")
    spare_devices=$(get_number "Spare Devices")
    events=$(get_number "Events")

    rows+=("$(jq -n \
        --arg device "$array" \
        --arg name "$name" \
        --arg raid_level "$raid_level" \
        --arg state "$state" \
        --arg array_size "$array_size" \
        --arg raid_devices "$raid_devices" \
        --arg total_devices "$total_devices" \
        --arg active_devices "$active_devices" \
        --arg working_devices "$working_devices" \
        --arg failed_devices "$failed_devices" \
        --arg spare_devices "$spare_devices" \
        --arg events "$events" \
        --arg mdadm_return_code "$mdadm_return_code" \
        '{
            ($device): {
                name: (if $name == "" then null else $name end),
                raid_level: (if $raid_level == "" then null else $raid_level end),
                array_size: (try ($array_size | tonumber) catch null),
                state: (if $state == "" then null else $state end),
                raid_devices: (try ($raid_devices | tonumber) catch null),
                total_devices: (try ($total_devices | tonumber) catch null),
                active_devices: (try ($active_devices | tonumber) catch null),
                working_devices: (try ($working_devices | tonumber) catch null),
                failed_devices: (try ($failed_devices | tonumber) catch null),
                spare_devices: (try ($spare_devices | tonumber) catch null),
                events: (try ($events | tonumber) catch null),
                mdadm_return_code: ($mdadm_return_code | tonumber),
                skipped: false,
                skipped_reason: null,
                sleeping_devices: [],
                check_errors: []
            }
        }')")
done

if ((${#rows[@]})); then
    printf '%s\n' "${rows[@]}" | jq -s 'add'
else
    printf '{}\n'
fi
