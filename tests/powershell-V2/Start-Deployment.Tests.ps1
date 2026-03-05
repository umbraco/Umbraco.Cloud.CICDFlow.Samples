BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot "..\..\V2\powershell\Start-Deployment.ps1"
}

Describe "Start-Deployment" {
    BeforeEach {
        $env:GITHUB_OUTPUT = Join-Path $TestDrive "github_output.txt"
        New-Item -Path $env:GITHUB_OUTPUT -ItemType File -Force | Out-Null
    }

    AfterEach {
        Remove-Item -Path $env:GITHUB_OUTPUT -ErrorAction SilentlyContinue
    }

    Context "When deployment starts successfully" {
        BeforeAll {
            $mockDeploymentId = "deploy-12345-abcde"
            $mockResponse = @{
                deploymentId = $mockDeploymentId
            }
        }

        It "Should return deployment ID for GITHUB vendor" {
            Mock Invoke-RestMethod {
                return $mockResponse
            }

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -CommitMessage "Test deployment" `
                -PipelineVendor "GITHUB"

            $output = Get-Content $env:GITHUB_OUTPUT
            $output | Should -Contain "deploymentId=$mockDeploymentId"
        }

        It "Should output Azure DevOps variable format" {
            Mock Invoke-RestMethod {
                return $mockResponse
            }

            $output = & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -CommitMessage "Test deployment" `
                -PipelineVendor "AZUREDEVOPS" 6>&1

            $vsoOutput = $output | Where-Object { $_ -match "##vso\[task\.setvariable" }
            $vsoOutput | Should -Not -BeNullOrEmpty
            $vsoOutput[0] | Should -BeLike "*deploymentId*$mockDeploymentId*"
        }

        It "Should output success message" {
            Mock Invoke-RestMethod {
                return $mockResponse
            }

            $output = & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -CommitMessage "Test deployment" `
                -PipelineVendor "TESTRUN" 6>&1

            $outputString = $output -join "`n"
            $outputString | Should -Match "Deployment Created Successfully"
        }
    }

    Context "When using deployment options" {
        It "Should pass NoBuildAndRestore option" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -NoBuildAndRestore $true `
                -PipelineVendor "TESTRUN"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Body -match '"noBuildAndRestore":\s*true'
            }
        }

        It "Should pass SkipVersionCheck option" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -SkipVersionCheck $true `
                -PipelineVendor "TESTRUN"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Body -match '"skipVersionCheck":\s*true'
            }
        }

        It "Should include commit message in request" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -CommitMessage "My custom commit message" `
                -PipelineVendor "TESTRUN"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Body -match 'My custom commit message'
            }
        }

        It "Should pass SkipPreserveUmbracoCloudJson option" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -SkipPreserveUmbracoCloudJson $true `
                -PipelineVendor "TESTRUN"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Body -match '"skipPreserveUmbracoCloudJson":\s*true'
            }
        }

        It "Should pass RunSchemaExtraction option" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -RunSchemaExtraction $false `
                -PipelineVendor "TESTRUN"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Body -match '"runSchemaExtraction":\s*false'
            }
        }
    }

    Context "When using custom BaseUrl" {
        It "Should use custom BaseUrl when provided" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -PipelineVendor "TESTRUN" `
                -BaseUrl "https://custom.api.com"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $URI -like "https://custom.api.com/*"
            }
        }
    }

    Context "When using unsupported vendor" {
        It "Should exit with error code for unknown vendor" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            }

            $output = & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -PipelineVendor "UNKNOWN" 6>&1

            $LASTEXITCODE | Should -Be 1
            ($output -join "`n") | Should -Match "Please use one of the supported Pipeline Vendors"
        }
    }

    Context "When API returns error" {
        It "Should output error on HTTP error" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Unauthorized")
            }

            $output = & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "invalid-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Development" `
                -PipelineVendor "TESTRUN" 6>&1 2>&1

            $outputString = $output -join "`n"
            $outputString | Should -Match "---Error---"
        }

        It "Should include exception message in error output" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Bad Request")
            }

            $output = & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "invalid-artifact" `
                -TargetEnvironmentAlias "Development" `
                -PipelineVendor "TESTRUN" 6>&1 2>&1

            $outputString = $output -join "`n"
            $outputString | Should -Match "Bad Request"
        }
    }

    Context "Request body structure" {
        It "Should include all required fields in request body" {
            Mock Invoke-RestMethod {
                return @{ deploymentId = "test-id" }
            } -Verifiable

            & $ScriptPath `
                -ProjectId "test-project" `
                -ApiKey "test-api-key" `
                -ArtifactId "artifact-123" `
                -TargetEnvironmentAlias "Production" `
                -CommitMessage "Deploy to prod" `
                -PipelineVendor "TESTRUN"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Body -match '"targetEnvironmentAlias"' -and
                $Body -match '"artifactId"' -and
                $Body -match '"commitMessage"' -and
                $Body -match '"skipPreserveUmbracoCloudJson"' -and
                $Body -match '"noBuildAndRestore"' -and
                $Body -match '"skipVersionCheck"' -and
                $Body -match '"runSchemaExtraction"'
            }
        }
    }
}
