# Azure Devops and PowerShell scripts
Quick setup for Azure Devops using PowerShell scripts to interact with Umbraco CI/CD Flow endpoints.

1. Place the yaml-scripts in your `devops` folder.
2. Powershell scripts should be placed in `devops/powershell`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml` and `cloud-deployment.yml`
3. Place the `cloud.gitignore` in the root of your repository.
4. Make a copy of the `.gitignore` from the Cloud Repository
    a. Call it `cloud.gitignore`
    b. place the file in the root of your repository 
