#!/usr/bin/env bash
set -eo pipefail
export LC_ALL=C

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

# Return the first field only if it is an integer.
get_number() {
    local value
    value=$(get_field "$1")

    awk -v value="$value" 'BEGIN {
        split(value, parts, /[[:space:]]+/)
        if (parts[1] ~ /^[0-9]+$/)
            print parts[1]
    }'
}

scan=$(mdadm --detail --scan)
rows=()

while IFS= read -r array; do
    [[ -n "$array" ]] || continue

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
                mdadm_return_code: ($mdadm_return_code | tonumber)
            }
        }')")
done < <(awk '$1 == "ARRAY" { print $2 }' <<< "$scan")

if ((${#rows[@]})); then
    printf '%s\n' "${rows[@]}" | jq -s 'add'
else
    printf '{}\n'
fi
