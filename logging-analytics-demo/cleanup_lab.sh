NAME="logging-analytics-demo"
COMPARTMENT_NAME=$NAME
GROUP_NAME="Logging-Analytics-SuperAdmins"
POLICY_NAME="Logging-Analytics-Demo-Policy"
LOGGROUP_NAME="$NAME-LogGroup"

UPLOAD_NAME=$NAME
#### get the id of the entities
echo "get the compartment id"
export COMPARTMENTID=`oci iam compartment list \
--access-level ACCESSIBLE \
--name $COMPARTMENT_NAME \
--compartment-id ocid1.tenancy.oc1..aaaaaaaanpuxsacx2rn22ycwc7ugp3sqzfvfhvyrrkmd7eanmvqd6bg7innq \
--compartment-id-in-subtree true | jq -r .data[].id`

DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
echo "$DATE:Workshop COMPARTMENTID=>$COMPARTMENTID" > cleanup.txt

echo "get the NameSpace"

export NAMESPACE=`oci os ns get | jq -r .data`

DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
echo "$DATE:Workshop NAMESPACE=>$NAMESPACE" >> cleanup.txt

echo "get the entites of the compartment"
rm -rf entity_ids.txt
oci log-analytics entity list \
--namespace-name $NAMESPACE \
--compartment-id $COMPARTMENTID \
--lifecycle-state ACTIVE \
| jq  '.data.items[] | "\(."are-logs-collected") \(."entity-type-internal-name") \(."entity-type-name") \(."name")   \(.id)"' | sed 's/"//g' | awk '{print $NF}' > entity_ids.txt

DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
echo "$DATE:Below are the loaded entities fo the workshop" >> cleanup.txt
cat entity_ids.txt >> cleanup.txt

	if [ ! -s entity_ids.txt ]
	then
		 echo "No entities"
	else
		### delete the entities
		echo "delete the entities of the compartment"
		input="entity_ids.txt"
		rm -rf delete_entities.sh
		while IFS= read -r line
		do
		 cat <<< EOT >> delete_entities.sh
		 	 oci log-analytics entity delete \
		     --entity-id $line \
		     --namespace-name $NAMESPACE \
		     --force
		 EOT
		done < "$input"
		cat delete_entities.sh
		chmod u+x delete_entities.sh 
		./delete_entities.sh	 
	fi



DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
echo "$DATE:removal of the entities is done" >> cleanup.txt

echo "get the upload list of the compartment"
export Upload_ref=`oci log-analytics upload list \
 --namespace-name $NAMESPACE | jq -r .data.items[].reference`
 
 	if [ -z $Upload_ref ]
	then
		 echo "No upload list"
	else
		DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
		echo "$DATE:Upload_ref=>$Upload_ref" >> cleanup.txt
		 
		oci log-analytics upload delete \
		--namespace-name $NAMESPACE \
		--upload-reference $Upload_ref \
		--force	
	fi
 


echo "get the log-group list"
export LOGGROUPID=`oci log-analytics log-group list \
--compartment-id $COMPARTMENTID   \
--display-name $LOGGROUP_NAME   \
--namespace-name $NAMESPACE | jq -r .data.items[].id` 

DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
echo "$DATE: LogGroup list=>$LOGGROUPID" >>   cleanup.txt

  if [ -z $LOGGROUPID ]
  then
     echo "log-group list is empty"
  else
	#### need ETAG to move on otherwise the delete doesnt work !
	###
	export ETAG=`oci log-analytics log-group get \
	--namespace-name $NAMESPACE \
	--log-group-id $LOGGROUPID | jq -r .etag` 

			 
	oci log-analytics log-group delete \
	--namespace-name $NAMESPACE       \
	--log-group-id $LOGGROUPID --if-match $ETAG \
	--force 
	
	DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
	echo "$DATE: LogGroup list deteted=>$LOGGROUPID" >>   cleanup.txt
  fi	
		


### offboard analytics
# oci log-analytics namespace offboard \
#--namespace-name $NAMESPACE

rm -rf entity_ids.txt delete_entities.sh

DATE=$(date +%d-%m-%Y"-"%H:%M:%S)
echo "$DATE: End of cleanup " >>   cleanup.txt

