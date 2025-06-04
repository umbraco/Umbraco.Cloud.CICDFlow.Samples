# GITHUB Actions and Bash scripts
Quick setup for GitHub Actions using bash scripts to interact with the Umbraco Cloud CI/CD Flow V2 endpoints.

> Work in Progress Warning. 
> We are still tweaking and building. Endpoints are prone to change or might even not be available.
> Please use the V1 scripts and endpoints.

1. Place the [`cloud.zipignore`](../../cloud.zipignore) from the root of this repository, in the root of your repository.
2. Copy the yaml-scripts from this folder into your `.github/workflows` folder.
3. Bash scripts should be placed in `.github/scripts`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml`, `cloud.artifact.yml` and `cloud-deployment.yml`
4. Make a copy of the `.gitignore` from the Cloud Project Repository (not from this sample repository)
    1. Call the copy `cloud.gitignore`
    2. place both files in the root of your repository
