#!/bin/bash

# Set required variables
projectId="$1"
deploymentId="$2"
apiKey="$3"

# Not required, defaults to 1200
timeoutSeconds="$4"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$5" 

if [[ -z "$timeoutSeconds" ]]; then
  timeoutSeconds=1200
fi

if [[ -z "$baseUrl" ]]; then
  baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#get-deployment-status
#
url="$baseUrl/v1/projects/$projectId/deployments/$deploymentId"

run=1
# Define function to call API and check status
function call_api {
  echo "=====> Requesting Status - Run number $run"
  response=$(curl -s -w "%{http_code}" -X GET $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
  responseCode=${response: -3}  
  content=${response%???}
  
  if [[ 10#$responseCode -eq 200 ]]; then
    status=$(echo $content | jq -Rnr '[inputs] | join("\\n") | fromjson | .deploymentState' )
    echo $(echo $content | jq -Rnr '[inputs] | join("\\n") | fromjson | .updateMessage' )
    return
  fi

  ## Let errors bubble forward 
  echo "Unexpected API Response Code: $responseCode"
  echo "---Response Start---"
  echo $content
  echo "---Response End---"
  exit 1
}

status="Pending" #Status set to get the while-loop running :)

while [[ $status == "Pending" || $status == "InProgress" || $status == "Queued" ]]; do
  call_api
  ((run++))

  # Handle timeout
  if [[ $SECONDS -gt $timeoutSeconds ]]; then
    echo "Timeout reached, exiting loop."
    break
  fi

  # Dont write if Deployment was finished
  if [[ $status == "Pending" || $status == "InProgress" || $status == "Queued" ]]; then
    echo "=====> Still Deploying - sleeping for 15 seconds"
    sleep 15
  fi
done

# Successfully deployed to cloud
if [[ $status == "Completed" ]]; then
  echo "Deployment completed successfully."
  exit 0
elif [[ $status == "Failed" ]]; then # Deployment has failed
  echo "Deployment failed."
  exit 1
else
  echo "Unexpected status: $status" # Unexpected deployment status - considered a fail
  exit 1
fi
