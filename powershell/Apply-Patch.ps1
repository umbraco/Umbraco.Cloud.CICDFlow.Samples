param (
    [Parameter(Position=0)]
    [string]
    $PatchFile,
    
    [Parameter(Position=1)]
    [string]
    $LatestDeploymentId,
    
    [Parameter(Position=3)]
    [string]
    $PipelineVendor,

    [Parameter(Position=3)]
    [string]
    $GitUserName = "github-actions",
    
    [Parameter(Position=4)]
    [string]
    $GitUserEmail = "github-actions@github.com"
)

git config user.name $GitUserName
git config user.email $GitUserEmail

If ($PipelineVendor -eq "AZUREDEVOPS"){
    # we need to checkout the specific branch to be able to commit bad to repo in Azure DevOps
    git checkout $env:BUILD_SOURCEBRANCHNAME
}


Write-Host "Testing the patch"
# Check if the patch has been applied already, skip if it has
git apply $PatchFile --reverse --ignore-space-change --ignore-whitespace --check
If ($LASTEXITCODE -eq 0) {
    Write-Host "Patch already applied => concluding the apply patch part"
    Exit 0
} Else {
    Write-Host "Patch not applied yet"
}

Write-Host "Checking if patch can be applied..."
# Check if the patch can be applied
git apply $PatchFile --ignore-space-change --ignore-whitespace --check
If ($LASTEXITCODE -eq 0) {
    Write-Host "Patch needed, trying now"
    git apply $PatchFile --ignore-space-change --ignore-whitespace

    switch ($PipelineVendor) {
        "GITHUB" {
            git add *
            git commit -m "Adding cloud changes since deployment $LatestDeploymentId [skip ci]"
            git push
            $updatedSha = git rev-parse HEAD
            
            # Record the new sha for the deploy
            "updatedSha=$($updatedSha)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        }
        "AZUREDEVOPS" {
            git add --all
            git commit -m "Adding cloud changes since deployment $LatestDeploymentId [skip ci]"
            git push --set-upstream origin $env:BUILD_SOURCEBRANCHNAME
            $updatedSha = git rev-parse HEAD

            # Record the new sha for the deploy
            Write-Host "##vso[task.setvariable variable=updatedSha;isOutput=true]$($updatedSha)"
        }
        "TESTRUN" {
            Write-Host $PipelineVendor
        }
        Default {
            Write-Host "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
            Write-Host "Currently supported are: GITHUB and AZUREDEVOPS"
            Exit 1
        }
    }
    Write-Host "Updated SHA: $updatedSha"
    Exit 0
} Else {
    Write-Host ""
    Write-Host "Patch cannot be applied - please check the output below for the problematic parts"
    Write-Host "================================================================================="
    git apply --reject $PatchFile --ignore-space-change --ignore-whitespace --check
    Exit 1
}