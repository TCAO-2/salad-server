#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /dev/sdX" >&2
    exit 2
fi

device=$(readlink -f -- "$1")
if [[ ! -b "$device" ]]; then
    echo "Not a block device: $1" >&2
    exit 2
fi

name=${device##*/}
stat_file="/sys/class/block/$name/stat"
state_dir="/tmp/salad-server/bloc/$name"
state_file="$state_dir/stat"

if [[ ! -r "$stat_file" ]]; then
    echo "Cannot read $stat_file" >&2
    exit 1
fi

mkdir -p -- "$state_dir"

current_stat=$(<"$stat_file")
now=$(date +%s)

write_state() {
    local timestamp=$1
    local stat_line=$2
    local tmp

    tmp=$(mktemp "$state_dir/.stat.XXXXXX")
    printf '%s\n%s\n' "$timestamp" "$stat_line" > "$tmp"
    mv -f -- "$tmp" "$state_file"
}

if [[ ! -r "$state_file" ]]; then
    write_state $now "$current_stat"
    printf '0\n'
    exit 0
fi

{
    IFS= read -r last_change || true
    IFS= read -r previous_stat || true
} < "$state_file"

if [[ "$current_stat" != "$previous_stat" ]]; then
    write_state "$now" "$current_stat"
fi

elapsed=$((now - last_change))
printf '%s\n' "$elapsed"
