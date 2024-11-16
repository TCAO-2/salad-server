#!/bin/bash

BUILD_SCRIPT=/opt/salad-server/scripts/create-data-integrity-report.sh
CHECK_SCRIPT=/opt/salad-server/scripts/check_data_integrity_from_report.py

SRC_DIR=/opt/salad-server/dev-utils/unit-tests/check-data-integrity/src/
DST_DIR=/opt/salad-server/dev-utils/unit-tests/check-data-integrity/dst/

SRC_REPORT=/opt/salad-server/dev-utils/unit-tests/check-data-integrity/report-src.txt
DST_REPORT=/opt/salad-server/dev-utils/unit-tests/check-data-integrity/report-dst.txt

_LOG_LEVEL_CONSOLE=$LOG_LEVEL_CONSOLE
export LOG_LEVEL_CONSOLE="TRACE"

rm -f $SRC_REPORT
rm -f $DST_REPORT

echo "Building src report..."
bash $BUILD_SCRIPT -d $SRC_DIR -f $SRC_REPORT

echo "Building dst report..."
bash $BUILD_SCRIPT -d $DST_DIR -f $DST_REPORT

echo "Checking reports..."
python3 $CHECK_SCRIPT $SRC_REPORT $DST_REPORT

export LOG_LEVEL_CONSOLE=$_LOG_LEVEL_CONSOLE
