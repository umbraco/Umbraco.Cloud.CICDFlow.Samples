#!/bin/bash

# Set required variables
patchFile="$1"
latestDeploymentId="$2"
pipelineVendor="$3"

# Not required, defaults to:
gitUserName="$4" # github-actions
gitUserEmail="$5"  # github-actions@github.com

if [[ -z "$gitUserName" ]]; then
    gitUserName="github-actions"
fi

if [[ -z "$gitUserEmail" ]]; then
    gitUserEmail="github-actions@github.com"
fi

git config user.name "$gitUserName"
git config user.email "$gitUserEmail"

echo "Testing the patch - errors might show up, and that is okay"
echo "=========================================================="
# Check if the patch has been applied already, skip if it has
if git apply "$patchFile" --reverse --ignore-space-change --ignore-whitespace --check; then
    echo "Patch already applied === concluding the apply patch part"
    exit 0

# check if the patch can be applied
elif git apply "$patchFile" --ignore-space-change --ignore-whitespace --check; then
    echo "Patch needed, trying to apply now"
    echo "================================="
    git apply "$patchFile" --ignore-space-change --ignore-whitespace
    git add *
    git commit -m "Adding cloud changes since deployment $latestDeploymentId [skip ci]"
    git push
    # record the new sha for the deploy
    updatedSha=$(git rev-parse HEAD)
    echo "Updated SHA: $updatedSha"
    
    ## Write the updated Sha to the pipelines variables for use in a later step
    if [[ "$pipelineVendor" == "GITHUB" ]]; then
        echo "updatedSha=$updatedSha" >> "$GITHUB_OUTPUT"
        exit 0
    elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
        echo "##vso[task.setvariable variable=updatedSha;isOutput=true]$updatedSha"
        exit 0
    elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
        echo $pipelineVendor
        exit 0
    else 
        echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
        echo "Currently supported are: GITHUB and AZUREDEVOPS"
        Exit 1
    fi

# Handle the case where the patch cannot be applied
else
    echo "Patch cannot be applied - please check the output below for the problematic parts"
    echo "================================================================================="
    git apply --reject "$patchFile" --ignore-space-change --ignore-whitespace --check
    exit 1
fi