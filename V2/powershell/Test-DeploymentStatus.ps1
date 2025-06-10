param(
    [Parameter(Position=0)]
    [string] 
    $ProjectId,

    [Parameter(Position=1)]
    [string] 
    $ApiKey,

    [Parameter(Position=2)]
    [string] 
    $DeploymentId,
    
    [Parameter(Position=3)]
    [int] 
    $TimeoutSeconds = 1200,

    [Parameter(Position=4)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
$BaseStatusUrl = "$BaseUrl/v2/projects/$ProjectId/deployments/$DeploymentId"

$timer = [Diagnostics.Stopwatch]::StartNew()

$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

function Request-Deployment-Status ([INT]$run){
    Write-Host "=====> Requesting Status - Run number $run"
    try {
        $response = Invoke-WebRequest -URI $url -Headers $headers -Method Get

        if ($response.StatusCode -eq 200) {
            $jsonResponse = ConvertFrom-Json $([String]::new($response.Content))

            Write-Host "DeploymentStatus: '$($jsonResponse.deploymentState)'"

            foreach ($item in $jsonResponse.deploymentStatusMessages){
                Write-Host "$($item.timestampUtc): $($item.message)"
            }
            
            return $jsonResponse
        }
    }
    catch 
    {
        Write-Host "---Error---"
        Write-Host $_.Exception.Message
        if ($null -ne $_.Exception.Response) {
            $responseStream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($responseStream)
            $responseBody = $reader.ReadToEnd()
            Write-Host "Response Body: $responseBody"
        }
        exit 1
    }
}

$run = 1
$url = $BaseStatusUrl

$statusesBeforeCompleted = ("Pending", "InProgress", "Queued")
Write-Host "Getting Status for Deployment: $($DeploymentId)"
do {

    $deploymentResponse = Request-Deployment-Status($run)
    $run++

    # Handle timeout
    if ($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds){
        throw "Timeout was reached"
    }
    
    # Dont write if Deployment was finished
    if ($statusesBeforeCompleted -contains $deploymentResponse.deploymentState){
        $sleepValue = 25
        Write-Host "=====> Still Deploying - sleeping for $sleepValue seconds"
        Start-Sleep -Seconds $sleepValue
        $LastModifiedUtc = $deploymentResponse.modifiedUtc.ToString("o")
        $url = "$BaseStatusUrl\?lastModifiedUtc=$($LastModifiedUtc)"
    }

} while (
    $statusesBeforeCompleted -contains $deploymentResponse.deploymentState
)

$timer.Stop()

# Successfully deployed to cloud
if ($deploymentResponse.deploymentState -eq 'Completed'){
    Write-Host "Deployment completed successfully"
    exit 0
}

# Deployment has failed
if ($deploymentResponse.deploymentState -eq 'Failed'){
    Write-Host "Deployment Failed"
    exit 1 
}

# Unexpected deployment status - considered a fail
Write-Host "Unexpected status: $deploymentResponse.deploymentState"
exit 1

