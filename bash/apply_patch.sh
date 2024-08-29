#!/bin/bash

# Set required variables
patchFile="$1"
latestDeploymentId="$2"
pipelineVendor="$3"
gitUserName="$4"
gitUserEmail="$5"  

git config user.name "$gitUserName"
git config user.email "$gitUserEmail"

if [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
    # we need to checkout the specific branch to be able to commit bad to repo in Azure DevOps
    git checkout ${BUILD_SOURCEBRANCHNAME}
fi

echo "Testing the patch - errors might show up, and that is okay"
echo "=========================================================="
# Check if the patch has been applied already, skip if it has
if git apply "$patchFile" --reverse --ignore-space-change --ignore-whitespace --check; then
    echo "Patch already applied === concluding the apply patch part"
    exit 0
else
    echo "Patch not applied yet"    
fi

echo "Checking if patch can be applied..."
# check if the patch can be applied
if git apply "$patchFile" --ignore-space-change --ignore-whitespace --check; then
    echo "Patch needed, trying to apply now"
    echo "================================="
    git apply "$patchFile" --ignore-space-change --ignore-whitespace
    
    ## Write the updated Sha to the pipelines variables for use in a later step
    if [[ "$pipelineVendor" == "GITHUB" ]]; then
        git add *
        git commit -m "Adding cloud changes since deployment $latestDeploymentId [skip ci]"
        git push

        # record the new sha for the deploy
        updatedSha=$(git rev-parse HEAD)
        echo "updatedSha=$updatedSha" >> "$GITHUB_OUTPUT"
        
    elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
        git add --all
        git commit -m "Adding cloud changes since deployment $latestDeploymentId [skip ci]"
        git push --set-upstream origin ${BUILD_SOURCEBRANCHNAME}
        
        # Record the new sha for the deploy
        updatedSha=$(git rev-parse HEAD)
        echo "##vso[task.setvariable variable=updatedSha;isOutput=true]$updatedSha"
        
    elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
        echo $pipelineVendor
        
    else 
        echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
        echo "Currently supported are: GITHUB and AZUREDEVOPS"
        Exit 1
    fi
    echo "Changes are applied successfully"
    echo ""
    echo "Updated SHA: $updatedSha"
    exit 0

# Handle the case where the patch cannot be applied
else
    echo ""
    echo "Patch cannot be applied - please check the output below for the problematic parts"
    echo "================================================================================="
    echo ""
    git apply -v --reject "$patchFile" --ignore-space-change --ignore-whitespace --check
    exit 1
fi