#!/usr/bin/bash

## Copyright 2020 Oracle, Inc.

## NOTES
#
# 1. Must be run in your home region. 
#
#
##

source "scripts/oci_functions.sh"
source "scripts/upload.sh"

day=$(date +%d)
month=$(date +%b)
year=$(date +%Y)

echo "Running demo setup script: $month-$day-$year" | tee setup.properties

NAME="logging-analytics-demo"
COMPARTMENT_NAME=$NAME
GROUP_NAME="Logging-Analytics-SuperAdmins"
POLICY_NAME="Logging-Analytics-Demo-Policy"
LOGGROUP_NAME="$NAME-LogGroup"

UPLOAD_NAME=$NAME

setup_compartment $COMPARTMENT_NAME
setup_iam_group $GROUP_NAME
setup_policies $POLICY_NAME

onboard
setup_loggroupid $LOGGROUP_NAME

update_timestamps
zip_files
upload_files
