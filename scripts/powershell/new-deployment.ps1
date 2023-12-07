param(
    [Parameter(Position=0)]    
    [string] 
    $BaseUrl,

    [Parameter(Position=1)]    
    [string] 
    $ProjectId,

    [Parameter(Position=2)]
    [string] 
    $ApiKey,

    [Parameter(Position=3)]
    [string] 
    $CommitMessage,
    
    [Parameter(Position=4)]
    [string] 
    $PipelineVendor
)


$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

$body = @{
    'commitMessage' = $CommitMessage
} | ConvertTo-Json

$url = "$BaseUrl/v1/projects/$ProjectId/deployments"

Write-Host "Posting to $url with commit message: $CommitMessage"
try {
    $response = Invoke-RestMethod -URI $url -Headers $headers -Method POST -Body $body
    $status = $response.deploymentState
    $deploymentId = $response.deploymentId

    if ($status -eq "Created") {

        Write-Host $response.updateMessage

        switch ($PipelineVendor) {
            "GITHUB" {
                "DEPLOYMENT_ID=$($deploymentId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
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
