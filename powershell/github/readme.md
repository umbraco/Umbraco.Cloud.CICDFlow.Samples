# GITHUB Workflows and Powershell scripts
Quick setup for GitHub Workflow using powershell scripts to interact with the Umbraco Cloud CI/CD Flow endpoints.

1. Place the yaml-pipelines in your `.github/workflows` folder.
2. Powershell scripts should be placed in `.github/powershell`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml` and `cloud-deployment.yml`
3. Place the `cloud.gitignore` in the root of your repository.
4. Make a copy of the `.gitignore` from the Cloud Repository
    a. Call the copy `cloud.gitignore`
    b. place the file in the root of your repository 

Remember to update the reference in the `main.yml` to point to your own repository.
