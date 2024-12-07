#!/bin/bash

# Stop the script on error.
set -e

# $1 -> Message file.





################################################################################
# Parameters
################################################################################

FROM="from@example.com"
TO="to@example.com"
SUBJECT="Salad server daily report"
SERVER="smtp.example.com:587"
SERVER_USER="from"
SERVER_PASSWORD="password"

header="From: ${FROM}\nTo: ${TO}\nSubject: ${SUBJECT}"
sed -i "1s/^/${header}\n/" $1

echo "swaks --from $FROM --to $TO --server $SERVER --tls \
--auth-user $SERVER_USER --auth-password $SERVER_PASSWORD --data @${1}"
