#!/bin/bash

# Set required variables
projectId="$1"
apiKey="$2"
deploymentId="$3"
downloadFolder="$4"
pipelineVendor="$5"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$6" 

if [[ -z "$baseUrl" ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#get-deployment-diff

changeUrl="$baseUrl/v1/projects/$projectId/deployments/$deploymentId/diff"
filePath="$downloadFolder/git-patch.diff"

# Get diff - stores file as git-patch.diff
function get_changes {
  mkdir -p $downloadFolder # ensure folder exists
  
  responseCode=$(curl -s -w "%{http_code}" -L -o "$filePath" -X GET $changeUrl \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")

  if [[ 10#$responseCode -eq 204 ]]; then
    echo "No Changes - You can continue"
    remoteChanges="no"
    return
  elif [[ 10#$responseCode -eq 200 ]]; then

    if [ -z "$(cat ${filePath})" ] ## If the patchfile is empty, we treat as no change
    then
        echo "No Changes - You can continue"
        remoteChanges="no"
        return
    fi

    echo "Changes detected"
    remoteChanges="yes"
    return
  fi
  echo "---Response Start---"
  echo $Response
  echo "---Response End---"
  echo "Unexpected response - see above"
  exit 1
}

if [[ -z "$deploymentId" ]]; then
  echo "I need a DeploymentId of an older deployment to download a git-patch"
  exit 1
fi

get_changes

## Write the latest deployment id to the pipelines variables for use in a later step
if [[ "$pipelineVendor" == "GITHUB" ]]; then
  echo "remoteChanges=$remoteChanges" >> "$GITHUB_OUTPUT"
  exit 0
elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
  echo "##vso[task.setvariable variable=remoteChanges;isOutput=true]$remoteChanges"
  exit 0
elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
  echo $pipelineVendor
  exit 0
fi

echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
echo "Currently supported are: GITHUB and AZUREDEVOPS"
Exit 1