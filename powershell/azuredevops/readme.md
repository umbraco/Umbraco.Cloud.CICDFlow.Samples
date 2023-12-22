# Azure Devops and PowerShell scripts
Quick setup for Azure Devops using PowerShell scripts to interact with Umbraco CI/CD Flow endpoints.

1. Place the [`cloud.zipignore`](../../cloud.zipignore) from the root of this repository, in the root of your repository.
2. Place the yaml-scripts in your `devops` folder.
3. Powershell scripts should be placed in `devops/powershell`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml` and `cloud-deployment.yml`
4. Make a copy of the `.gitignore` from the Cloud Project Repository (not from this sample repository)
    a. Call the copy `cloud.gitignore`
    b. place both files in the root of your repository
