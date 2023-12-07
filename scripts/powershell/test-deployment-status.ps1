param(
    [Parameter(Position=0)]
    [string] 
    $BaseUrl,
    
    [Parameter(Position=1)]
    [string] 
    $ProjectId,
    
    [Parameter(Position=2)]
    [string] 
    $DeploymentId,
    
    [Parameter(Position=3)]
    [string] 
    $ApiKey,
    
    [Parameter(Position=4)]
    [int] 
    $TimeoutSeconds = 1200
)

$timer = [Diagnostics.Stopwatch]::StartNew()

$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}
$url = "$BaseUrl/v1/projects/$ProjectId/deployments/$DeploymentId"

function Request-Deployment-Status ([INT]$run){
    Write-Host "=====> Requesting Status - Run number $run"
    try {
        $response = Invoke-WebRequest -URI $url -Headers $headers 
        if ($response.StatusCode -eq 200) {

            $jsonResponse = ConvertFrom-Json $([String]::new($response.Content))

            Write-Host $jsonResponse.updateMessage
            return $jsonResponse.deploymentState
        }
    }
    catch 
    {
        Write-Host "---Error---"
        Write-Host $_
        exit 1
    }
}

$run = 1

$statusesBeforeCompleted = ("Pending", "InProgress", "Queued")

do {
    $deploymentStatus = Request-Deployment-Status($run)
    $run++

    # Handle timeout
    if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds){
        throw "Timeout was reached"
    }
    
    # Dont write if Deployment was finished
    if ($statusesBeforeCompleted -contains $deploymentStatus){
        Write-Host "=====> Still Deploying - sleeping for 15 seconds"
        Start-Sleep -Seconds 15
    }

} while (
    $statusesBeforeCompleted -contains $deploymentStatus
)

$timer.Stop()

# Successfully deployed to cloud
if ($deploymentStatus -eq 'Completed'){
    Write-Host "Deployment completed successfully"
    exit 0
}

# Deployment has failed
if ($deploymentStatus -eq 'Failed'){
    Write-Host "Deployment Failed"
    exit 1 
}

# Unexpected deployment status - considered a fail
Write-Host "Unexpected status: $deploymentStatus"
exit 1

