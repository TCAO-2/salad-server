#!/bin/bash

CHECK_SCRIPT=/opt/salad-server/scripts/check_data_integrity_from_report.py
SRC_REPORT=/opt/salad-server/dev-utils/unit-tests/check-data-integrity/report-src.txt
DST_REPORT=/opt/salad-server/dev-utils/unit-tests/check-data-integrity/report-dst.txt

python3 $CHECK_SCRIPT $SRC_REPORT $DST_REPORT
