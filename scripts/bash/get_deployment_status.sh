#!/bin/bash

# Set variables
baseUrl="$1"
projectId="$2"
deploymentId="$3"
url="$baseUrl/v1/projects/$projectId/deployments/$deploymentId"
apiKey="$4"

# Define function to call API and check status
function call_api {
  response=$(curl --insecure -s -X GET $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
  echo "$response"
  status=$(echo $response | jq -r '.deploymentState')
}

# Call API and check status
call_api
while [[ $status == "Pending" || $status == "InProgress" || $status == "Queued" ]]; do
  echo "Status is $status, waiting 15 seconds..."
  sleep 15
  call_api
  # Wait max 20 minutes. This is a variable value depending on your project
  if [[ $SECONDS -gt 1200 ]]; then
    echo "Timeout reached, exiting loop."
    break
  fi
done

# Check final status
if [[ $status == "Completed" ]]; then
  echo "Deployment completed successfully."
elif [[ $status == "Failed" ]]; then
  echo "Deployment failed."
  exit 1
else
  echo "Unexpected status: $status"
  exit 1
fi
