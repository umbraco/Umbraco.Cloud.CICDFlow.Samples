#!/bin/bash

# Set variables
projectId="$1"
apiKey="$2"
downloadFolder="$3"

# Get latest deployment id
function get_latest_deployment_id {
  deployments_url="https://api.cloud.umbraco.com/v1/projects/$projectId/deployments?skip=0&take=1&includenulldeployments=false"
  response=$(curl --insecure -s -X GET $deployments_url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
  echo "$response"
  latestDeploymentId=$(echo $response | jq -r '.deployments[0].deploymentId')
}

# Get diff - stores file as git-patch.diff
function get_changes {
  mkdir -p $downloadFolder # ensure folder exists
  change_url="https://api.cloud.umbraco.com/v1/projects/$projectId/deployments/$latestDeploymentId/diff"
  responseCode=$(curl --insecure -s -w "%{http_code}" -L -o "$downloadFolder/git-patch.diff" -X GET $change_url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
  echo "Response code: $responseCode"
}

get_latest_deployment_id

# deployment id found
if [ -z "$latestDeploymentId" ]; then
  echo "Deployment id not found."
  exit 1
fi

get_changes

if [[ 10#$responseCode -eq 204 ]]; then # Http 204 No Content means that there are no changes
  echo "No changes"
  rm -fr $downloadFolder/git-patch.diff
  echo "##vso[task.setvariable variable=remoteChanges;isOutput=true]no"
elif [[ 10#$responseCode -eq 200 ]]; then # Http 200 downloads the file and set a few variables for pipeline
  echo "Changes - check file - $downloadFolder/git-patch.diff"
  echo "##vso[task.setvariable variable=remoteChanges;isOutput=true]yes"
  echo "##vso[task.setvariable variable=lastestDeploymentId;isOutput=true]$latestDeploymentId"
  echo "##vso[task.setvariable variable=remoteChangeFile;isOutput=true]git-patch.diff"
else
  echo "Unexpected status: $responseCode"
  exit 1
fi