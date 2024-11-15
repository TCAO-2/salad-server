# Check the differences between the source and the destination folders
# before a backup. This script is using data integrity reports
# that have to be generated first using create-data-integrity-report script.
#
# Usage:
#     python3 check_data_integrity_from_report.py <src_report> <dst_report>
#
# Each lines of the report files must be of format:
#     <file_hash> <timestamp> <file_path_and_name>
#
# Result logged for each file:
#     | Situation    | Comment                             | Log level |
#     |--------------|-------------------------------------|-----------|
#     | Same file    |                                     | TRACE     |
#     | Only in src  | Would be created during backup      | VERB      |
#     | Newer in src | Would be updaded during backup      | VERB      |
#     | Only in dst  | Would be deleted during backup      | INFO      |
#     | Newer in dst | Would be updated during backup      | WARN      |
#     | Corrupted    | Same timestamp but different hashes | ERROR     |

import os
import sys
from logger_caller import logger





################################################################################
# Helper functions
################################################################################

def reports_to_hashmap(src_file, dst_file):
    """Merge the two reports in a unique hashmap with all infos for each file."""
    hashmap = {}
    with open(src_file, "r") as report_file:
        for line in report_file:
            file_hash, timestamp, filename = line.strip().split(maxsplit=2)
            filename_hash = hash(filename)
            hashmap[filename_hash] = {
                "src_file_hash": file_hash,
                "src_timestamp": timestamp,
                "filename": filename
            }
    with open(dst_file, "r") as report_file:
        for line in report_file:
            file_hash, timestamp, filename = line.strip().split(maxsplit=2)
            filename_hash = hash(filename)
            if filename_hash not in hashmap:
                hashmap[filename_hash] = {
                    "dst_file_hash": file_hash,
                    "dst_timestamp": timestamp,
                    "filename": filename
                }
            else:
                hashmap[filename_hash]["dst_file_hash"] = file_hash
                hashmap[filename_hash]["dst_timestamp"] = timestamp
    return hashmap



def process_hashmap(hashmap):
    """Process the hashmap to evaluate if src and dst changes are consistent."""
    for element in hashmap.items():
        metadata = element[1]
        filename = metadata.get("filename")
        keys = metadata.keys()
        if "src_timestamp" in keys and "dst_timestamp" in keys:
            # File is on both reports, compare the metadata.
            src_file_hash = metadata.get("src_file_hash")
            src_timestamp = metadata.get("src_timestamp")
            dst_file_hash = metadata.get("dst_file_hash")
            dst_timestamp = metadata.get("dst_timestamp")
            if src_timestamp == dst_timestamp:
                if src_file_hash == dst_file_hash:
                    logger(f"same same\t{filename}", "TRACE")
                else:
                    logger(f"corrupted\t{filename}", "ERROR")
            elif src_timestamp < dst_timestamp:
                logger(f"newer in dst\t{filename}", "WARN")
            else:
                logger(f"newer in src\t{filename}", "VERB")
        elif "src_timestamp" in keys:
            logger(f"only in src\t{filename}", "VERB")
        else:
            logger(f"only in dst\t{filename}", "INFO")





################################################################################
# Init
################################################################################

argv = sys.argv

if len(argv) < 3:
    raise Exception("Missing script argument")

src_file = argv[1]
dst_file = argv[2]

if not os.path.isfile(src_file):
    raise FileNotFoundError(f"Report file '{src_file}' does not exist!")

if not os.path.isfile(dst_file):
    raise FileNotFoundError(f"Report file '{dst_file}' does not exist!")





################################################################################
# Main
################################################################################

hashmap = reports_to_hashmap(src_file, dst_file)
process_hashmap(hashmap)
