# GITHUB Actions and Bash scripts
Quick setup for GitHub Actions using bash scripts to interact with the Umbraco Cloud CI/CD Flow endpoints.

1. Place the [`cloud.zipignore`](../../cloud.zipignore) from the root of this repository, in the root of your repository.
2. Copy the following yaml-scripts from this folder into your `.github/workflows` folder:
    - `main.yml`
    - `cloud-sync.yml`
    - `cloud-deployment.yml`
3. Bash scripts should be placed in `.github/scripts`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml` and `cloud-deployment.yml`
4. Make a copy of the `.gitignore` from the Cloud Project Repository (not from this sample repository)
    a. Call the copy `cloud.gitignore`
    b. place both files in the root of your repository

## Alternative to main.yml
The `main.yml` workflow always automatically triggers when pushed to `main` branch. It will always try to run the two jobs `cloud-sync` and `cloud-deployment`.

In some instances you may want to manually trigger a deployment and optionally skip the `cloud-sync` job, and here the `main-with-manual-trigger.yml` workflow comes in handy.

It will allow you to manually trigger a deployment to cloud. Via a toggle you are able to skip the "cloud-sync" section of the pipeline. 

All you need to do is copy `main-with-manual-trigger.yml` into your `.github/workflows` folder.

The `main-with-manual-trigger.yml` workflow is prepared to also be able to trigger automatically:
1. Make sure `main.yml` (the old one) will not trigger - you can delete it or rename the extension.
2. In `main-with-manual-trigger.yml` workflow uncomment lines 5 to 9.
3. optionally rename the new pipeline to `main.yml` or what you like, but keep the 'yml-extension'.

# Deployment Status
You can check any CICD deployment status by a given deployment id. 
This can be helpful if you need to determine if a deployment is still active or if it completed (by failure or success) without having to run and wait for a new deployment.

You need to call the [Get Deployment Status endpoint](https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#get-deployment-status), in your favorite tool, like Postman or similar.