function getocid() 
{
  response=$1
  ocid_rx='\"id\":\s\"([^\"]+)\"'
  [[ "$response" =~ $ocid_rx ]]
  ocid=${BASH_REMATCH[1]}
  echo $ocid
}
