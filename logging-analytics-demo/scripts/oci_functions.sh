source "scripts/common.sh"

setup_compartment()
{
  name=$1
  echo "Checking to see if compartment $name already exists"
  compartmentcheck_out=$(oci iam compartment list \
                          | jq -r '.data[] | select (.name=="'"$name"'") | .id')

  if [ -z $compartmentcheck_out ]
  then
     echo "  Does not exist yet, create compartment"
     compartment_out=$(oci iam compartment create --compartment-id $OCI_TENANCY \
                        --name "$name" \
                        --description "Compartment for Logging Analytics demo resources")
     COMPARTMENTID=$(getocid "$compartment_out")
  else
     echo "  Already exists"
     COMPARTMENTID=$compartmentcheck_out
  fi

  if [ -z $COMPARTMENTID ]
  then
     echo "  Failed to get OCID - exiting"
     exit 1
  else
     echo "  Compartment OCID=$COMPARTMENTID" | tee -a setup.properties
  fi
}

setup_loggroupid()
{
  name=$1

  echo "Checking to see if log group $name already exists"
  loggroupcheck_out=$(oci log-analytics log-group list \
                       --namespace-name $NAMESPACE \
                       --compartment-id $COMPARTMENTID \
                      | jq -r '.data.items[] | select (."display-name"=="'"$name"'") | .id')


  if [ -z $loggroupcheck_out ]
  then
    echo "  Does not exist yet, create log group"
    loggroup_out=$(oci log-analytics log-group create \
                    --compartment-id $COMPARTMENTID   \
                    --display-name "$name"   \
                    --namespace-name $NAMESPACE       \
                    --description "Store all logs uploaded for the Logging Analytics demo setup")
    LOGGROUPID=$(getocid "$loggroup_out")
  else
    echo "  Already exists"
    LOGGROUPID=$loggroupcheck_out
  fi

  if [ -z $LOGGROUPID ]
  then
     echo "  Failed to get OCID - exiting"
     exit 1
  else
     echo "  Log Group OCID=$LOGGROUPID" |tee -a setup.properties
  fi
}

function setup_iam_group()
{
  name="$1"
  echo "Checking to see if group $name already exists"
  groupcheck_out=$(oci iam group list \
                    | jq -r '.data[] | select (.name=="'"$name"'") | .id')
  if [ -z $groupcheck_out ]
  then
    echo "  Does not exist yet, create group"
    group_out=$(oci iam group create --name "$name" \
            --description "Super-Administrator group for Logging Analytics. Users of this group can perform all operations in Logging Analytics and Management Dashboards.")
    GROUPID=$(getocid "$group_out")
  else
    echo "  Already exists"
    GROUPID=$groupcheck_out
  fi

  if [ -z $GROUPID ]
  then
     echo "  Failed to get OCID - exiting"
     exit 1
  else
     echo "  Group OCID=$GROUPID" | tee -a setup.properties
  fi
}

function setup_policies()
{
  name=$1
  echo "Checking to see if policy $name already exists"
  policycheck_out=$(oci iam policy list --compartment-id $OCI_TENANCY \
                      | jq -r '.data[] | select (.name=="'"$name"'") | .id')

  if [ -z $policycheck_out ]
  then
    echo "  Does not exist yet, create policy"
    policy_out=$(oci iam policy create --compartment-id $OCI_TENANCY \
            --name "$name" \
            --description "Policy set for Logging Analytics demo" \
            --statements '[
       "allow service loganalytics to READ loganalytics-features-family in tenancy",
       "allow group Logging-Analytics-SuperAdmins to READ compartments in tenancy",
       "allow group Logging-Analytics-SuperAdmins to MANAGE loganalytics-features-family in tenancy",
       "allow group Logging-Analytics-SuperAdmins to MANAGE loganalytics-resources-family in compartment Logging-Analytics-Demo",
       "allow group Logging-Analytics-SuperAdmins to MANAGE management-dashboard-family in compartment Logging-Analytics-Demo",
       "allow group Logging-Analytics-SuperAdmins to READ metrics IN tenancy",
       "allow group Logging-Analytics-SuperAdmins to READ users IN tenancy"
       ]')
    POLICYID=$(getocid "$policy_out")
  else
    echo "  Already exists"
    POLICYID=$policycheck_out
  fi

  if [ -z $POLICYID ]
  then
     echo "  Failed to get OCID - exiting"
     exit 1
  else
     echo "  Policy OCID=$POLICYID" | tee -a setup.properties
  fi
}

function onboard()
{
  echo "Checking to see if tenancy already onboarded to Logging Analytics"
  onboardcheck_out=$(oci log-analytics namespace list \
                      --compartment-id $OCI_TENANCY)

  namespace_rx='\"namespace-name\":\s\"([^\"]+)\"'
  [[ "$onboardcheck_out" =~ $namespace_rx ]]
  NAMESPACE=${BASH_REMATCH[1]}

  onboarded_rx='\"is-onboarded\":\s(\w+)'
  [[ "$onboardcheck_out" =~ $onboarded_rx ]]
  isonboarded=${BASH_REMATCH[1]}

  echo "  Namespace=$NAMESPACE" |tee -a setup.properties
  echo "  isOnboarded=$isonboarded"

  ## If customer is not onboarded, onboard them.
  if [ $isonboarded == "false" ]
    then
        echo "  Onboarding tenancy to Logging Analytics in this region."
        onboard_out=$(oci log-analytics namespace onboard \
                  --namespace-name $NAMESPACE)
        echo $onboard_out
        sleep 10
  fi
}
