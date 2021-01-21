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
cp setup.properties installation_steps.txt

NAME="LoggingAnalytics"
COMPARTMENT_NAME=$NAME


echo "get the compartment id"
export COMPARTMENTID=`oci iam compartment list \
--access-level ACCESSIBLE \
--name $COMPARTMENT_NAME \
--compartment-id ocid1.tenancy.oc1..aaaaaaaanpuxsacx2rn22ycwc7ugp3sqzfvfhvyrrkmd7eanmvqd6bg7innq \
--compartment-id-in-subtree true | jq -r .data[].id`


GROUP_NAME="Logging-Analytics-SuperAdmins"
POLICY_NAME="LoggingAnalytics"
LOGGROUP_NAME="$NAME-LogGroup"

UPLOAD_NAME=$NAME

setup_compartment $COMPARTMENT_NAME
setup_iam_group $GROUP_NAME
setup_policies $POLICY_NAME

echo  "NAME=>$NAME" >>installation_steps.txt
echo "COMPARTMENT_NAME=>$COMPARTMENT_NAME"  >> installation_steps.txt
echo "GROUP_NAME=> $GROUP_NAME"  >> installation_steps.txt
echo "POLICY_NAME=>$POLICY_NAME"  >> installation_steps.txt
echo "LOGGROUP_NAME=>$LOGGROUP_NAME"   >> installation_steps.txt
echo "UPLOAD_NAME=>$UPLOAD_NAME"  >> installation_steps.txt


onboard
setup_loggroupid $LOGGROUP_NAME

update_timestamps
zip_files
upload_files
