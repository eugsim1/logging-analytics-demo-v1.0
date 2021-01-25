source "scripts/common.sh"

function update_timestamps()
{
   echo "from update_timestamps=>Dont Create log directories"
#  rm -rf logs/*
#  mkdir -p logs/{db,syslog,oci-vcn-flow,oci-api-gw,cisco-asa,F5,juniper}
   echo "from update_timestamps=>Dont change Log Record timestamps"
#  perl scripts/time_shift.pl \
#    -input_dir  source/  \
#    -output_dir logs/    \
#    -shift_to today 
}

zip_files()
{
  echo "Compressing files"
  rm -f logs/oci-vcn-flow/vcn_flow_logs.zip && zip -r logs/oci-vcn-flow/vcn_flow_logs.zip logs/oci-vcn-flow/* > /dev/null
  rm -f logs/oci-api-gw/oci_api_gw_access.zip && zip -r logs/oci-api-gw/oci_api_gw_access.zip logs/oci-api-gw/access/ > /dev/null
  rm -f logs/oci-api-gw/oci_api_gw_exec.zip && zip -r logs/oci-api-gw/oci_api_gw_exec.zip logs/oci-api-gw/exec/ > /dev/null
}

get_entity()
{
  entity=$1
  type=$2
  WorkshopUser_COMPARTMENTID=$3

  cmd="oci log-analytics entity list    \
        --namespace-name $NAMESPACE     \
        --compartment-id $WorkshopUser_COMPARTMENTID \
        --all                           \
        | jq -r '.data.items[] | select (.name==\"$entity\" and .\"entity-type-internal-name\"==\"$type\" and .\"lifecycle-state\"==\"ACTIVE\") | .id' \
        | tail -1 "

  ENTITYID=$(eval "$cmd")
}

create_entity()
{
  entity=$1
  type=$2
  WorkshopUser_COMPARTMENTID=$3

  get_entity $entity $type $WorkshopUser_COMPARTMENTID
  if [ ! -z $ENTITYID ]
    then
      echo "  Entity $entity already exists"
      return 0
  fi

  cmd="oci log-analytics entity create \
      --namespace-name $NAMESPACE     \
      --compartment-id $WorkshopUser_COMPARTMENTID \
      --name $entity                  \
      --entity-type-name $type"
  cmd_out=$($cmd)

  if [ -z "$cmd_out" ]
  then
    echo "  Unable to create entity $entity"
    exit 1
  else
    ENTITYID=$(getocid "$cmd_out")

    if [ -z $ENTITYID ]
    then
       echo "  Failed to get Entity OCID - exiting"
       exit 1
    else
       echo "  Created Entity $entity ($ENTITYID)"
    fi
  fi
}

upload()
{
  logsource="$1"
  file=$2
  entity_id=$3

  filename=`basename $file`

  entity_string=""
  if [ ! -z $entity_id ]
    then
    entity_string="--entity-id $entity_id"
  fi

  cmd="oci log-analytics upload upload-log-file  \
        --namespace-name $NAMESPACE              \
        --log-source-name $(echo \"$logsource\") \
        --upload-name $UPLOAD_NAME               \
        --filename $(echo \"$filename\")         \
        --opc-meta-loggrpid $LOGGROUPID          \
        --file $(echo \"$file\") $entity_string"

  echo "  Uploading $filename in logsource $logsource with upload name $UPLOAD_NAME with loggrpid $LOGGROUPID with entity $entity_string"
  eval "$cmd > /dev/null"
}

upload_pattern()
{
  pattern=$1
  log_source=$2
  id=$3
  for file in $pattern
  do
    upload "$log_source" "$file" "$id"
  done
}

upload_files()
{
  WorkshopUser_COMPARTMENTID=$1
  echo "Uploading Logs for user $WorkshopUser"
  sleep 10
  create_entity db1-$WorkshopUser omc_oracle_db_instance $WorkshopUser_COMPARTMENTID
  echo "uploading logs/db with entity $ENTITYID"
  upload_pattern 'logs/db/*' 'Database Alert Logs' $ENTITYID
  echo

  create_entity dbhost1.oracle.com-$WorkshopUser omc_host_linux $WorkshopUser_COMPARTMENTID
  echo "uploading logs/syslog/ with entity $ENTITYID"
  upload_pattern 'logs/syslog/*' 'Linux Syslog Logs' $ENTITYID
  echo

  create_entity bigip-ltm-dmz1.oracle.com-$WorkshopUser omc_host_linux $WorkshopUser_COMPARTMENTID
  echo "uploading logs/F5/ with entity $ENTITYID"
  upload_pattern 'logs/F5/*' 'F5 Big IP Logs' $ENTITYID
  echo

# create_entity cisco-asa1.oracle.com omc_host_linux
# upload_pattern 'logs/cisco-asa/*' 'Cisco ASA Logs' $ENTITYID

  create_entity srx-test.oracle.com-$WorkshopUser omc_host_linux $WorkshopUser_COMPARTMENTID
  echo "uploading logs/juniper/ with entity $ENTITYID"
  upload_pattern 'logs/juniper/*' 'Juniper SRX Syslog Logs' $ENTITYID
  echo

  ENTITYID=""
  echo "uploading logs/oci-vcn-flow/ with entity $ENTITYID"
  upload_pattern 'logs/oci-vcn-flow/*.zip' 'OCI VCN Flow Logs'
  echo

  create_entity apigw1.oracle.com-$WorkshopUser oci_api_gateway $WorkshopUser_COMPARTMENTID
  echo "uploading logs/oci-api-gw/*access with entity $ENTITYID"
  upload_pattern 'logs/oci-api-gw/*access.zip' 'OCI API Gateway Access Logs'     $ENTITYID
  echo "uploading logs/oci-api-gw/*exec with entity $ENTITYID"
  upload_pattern 'logs/oci-api-gw/*exec.zip'   'OCI API Gateway Execution Logs'  $ENTITYID
}
