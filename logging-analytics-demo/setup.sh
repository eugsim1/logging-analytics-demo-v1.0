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
cat<<EOF>defined_tags.json
{
	"Oracle-Tags": {
		"ResourceAllocation": "Logging-Analytics"
	}
}
EOF

export NAME="LoggingAnalytics" ### root compartment for the labs
export COMPARTMENT_NAME=$NAME
export GROUP_NAME="Logging-Analytics-SuperAdmins"
export POLICY_NAME="LoggingAnalytics"

export UPLOAD_NAME=$NAME

export WorkshopUser=$1
export LOGGROUP_NAME="$NAME-LogGroup-$WorkshopUser"

if [ -z $WorkshopUser ]
then
echo "Add your userId to the setup.sh script as ./setup.sh analytics00X"
exit 0
fi


echo "get the compartment id for the compartment $NAME"
export COMPARTMENTID=`oci iam compartment list \
--access-level ACCESSIBLE \
--name $COMPARTMENT_NAME \
--lifecycle-state ACTIVE \
--compartment-id ocid1.tenancy.oc1..aaaaaaaanpuxsacx2rn22ycwc7ugp3sqzfvfhvyrrkmd7eanmvqd6bg7innq \
--compartment-id-in-subtree true | jq -r .data[].id`




setup_compartment $COMPARTMENT_NAME $WorkshopUser $COMPARTMENTID
setup_iam_group $GROUP_NAME
setup_policies $POLICY_NAME

echo "NAME=>$NAME" >>installation_steps.txt
echo "COMPARTMENT_NAME=>$COMPARTMENT_NAME"  >> installation_steps.txt
echo "GROUP_NAME=> $GROUP_NAME"  >> installation_steps.txt
echo "POLICY_NAME=>$POLICY_NAME"  >> installation_steps.txt
echo "LOGGROUP_NAME=>$LOGGROUP_NAME"   >> installation_steps.txt
echo "UPLOAD_NAME=>$UPLOAD_NAME"  >> installation_steps.txt



onboard

export WorkshopUser_COMPARTMENTID=`oci iam compartment list \
--access-level ACCESSIBLE \
--name $WorkshopUser \
--lifecycle-state ACTIVE \
--compartment-id ocid1.tenancy.oc1..aaaaaaaanpuxsacx2rn22ycwc7ugp3sqzfvfhvyrrkmd7eanmvqd6bg7innq \
--compartment-id-in-subtree true | jq -r .data[].id`

setup_loggroupid $LOGGROUP_NAME $WorkshopUser_COMPARTMENTID

update_timestamps
zip_files
upload_files $WorkshopUser_COMPARTMENTID
