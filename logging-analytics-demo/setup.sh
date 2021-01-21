#!/usr/bin/bash

## Copyright 2021 Oracle, Inc.

## NOTES modified by Eugene Simos
#
# 1. Must be run in your home region. 
#
#
##
#!/bin/bash

source "scripts/oci_functions.sh"
source "scripts/upload.sh"

day=$(date +%d)
month=$(date +%b)
year=$(date +%Y)

echo "Running demo setup script: $month-$day-$year" | tee setup.properties
cp setup.properties installation_steps.txt

export NAME="LoggingAnalytics"
export COMPARTMENT_NAME=$NAME


echo "get the compartment id for the compartment $NAME"
export COMPARTMENTID=`oci iam compartment list \
--access-level ACCESSIBLE \
--name $COMPARTMENT_NAME \
--lifecycle-state ACTIVE \
--compartment-id ocid1.tenancy.oc1..aaaaaaaanpuxsacx2rn22ycwc7ugp3sqzfvfhvyrrkmd7eanmvqd6bg7innq \
--compartment-id-in-subtree true | jq -r .data[].id`


export GROUP_NAME="Logging-Analytics-SuperAdmins"
export POLICY_NAME="LoggingAnalytics"
export LOGGROUP_NAME="$NAME-LogGroup"

export UPLOAD_NAME=$NAME

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
