param(
    [Parameter(Position=0)]    
    [string] 
    $ProjectId,

    [Parameter(Position=1)]
    [string] 
    $ApiKey,

    [Parameter(Position=2)]
    [string] 
    $CommitMessage,
    
    [Parameter(Position=3)]
    [string] 
    $PipelineVendor, ## GITHUB or AZUREDEVOPS

    [Parameter(Position=4)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#create-the-deployment
#

$url = "$BaseUrl/v1/projects/$ProjectId/deployments"

$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

$body = @{
    'commitMessage' = $CommitMessage
} | ConvertTo-Json

Write-Host "Posting to $url with commit message: $CommitMessage"
try {
    $response = Invoke-RestMethod -URI $url -Headers $headers -Method POST -Body $body
    $status = $response.deploymentState
    $deploymentId = $response.deploymentId

    if ($status -eq "Created") {

        Write-Host $response.updateMessage

        switch ($PipelineVendor) {
            "GITHUB" {
                "deploymentId=$($deploymentId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
            }
            "AZUREDEVOPS" {
                Write-Host "##vso[task.setvariable variable=deploymentId;]$($deploymentId)"
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

        Write-Host "Deployment Created Successfully => $($deploymentId)"
        exit 0
    }

    Write-Host "---Response Start---"
    Write-Host $response
    Write-Host "---Response End---"
    Write-Host "Unexpected response - see above"
    exit 1
}
catch {
    Write-Host "---Error---"
    Write-Host $_
    exit 1
}
