# GITHUB Actions and Bash scripts
Quick setup for GitHub Actions using bash scripts to interact with the Umbraco Cloud CI/CD Flow endpoints.

1. Place the [`cloud.zipignore`](../../cloud.zipignore) from the root of this repository, in the root of your repository.
2. Copy the yaml-scripts from this folder into your `.github/workflows` folder.
3. Bash scripts should be placed in `.github/scripts`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml` and `cloud-deployment.yml`
4. Make a copy of the `.gitignore` from the Cloud Project Repository (not from this sample repository)
    a. Call the copy `cloud.gitignore`
    b. place both files in the root of your repository

## Manually triggered workflows
A couple of workflows you are able to trigger manually, which are designed to help resolve deployment issues you might encounter.

If you want to use the workflows, you need to copy the files to your own repository's `.github/workflows` folder.

Currently only available for GitHub with PowerShell scripts.

### manual-deployment.yml (Work in progress)
Allows you to manually trigger a deployment to cloud. Via a toggle you are able to skip the "cloud-sync" section of the pipeline. 

This is helpful if the "cloud-sync" somehow is blocking a deployment, due to changes from cloud cannot be applied back to local repository, because this already happened previously, but the deployment failed. 

### manual-status.yml
Allows you to run a deployment status check on a given deployment id. 
This can be helpful if you need to determine if a deployment is still active or if it completed (by failure or success).

This corresponds to calling the [Get Deployment Status endpoint](https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#get-deployment-status).  

Requires the updated `get_deployment_status.sh` script from this branch.