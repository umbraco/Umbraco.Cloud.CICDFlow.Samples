# GITHUB Actions and Bash scripts
Quick setup for GitHub Actions using bash scripts to interact with the Umbraco Cloud CI/CD Flow endpoints.

1. Place the [`cloud.zipignore`](../../cloud.zipignore) from the root of this repository, in the root of your repository.
2. Copy the yaml-scripts from this folder into your `.github/workflows` folder.
3. Bash scripts should be placed in `.github/scripts`.
    - Feel free to place scripts somewhere else, but you need to update the paths in the `cloud-sync.yml` and `cloud-deployment.yml`
4. Make a copy of the `.gitignore` from the Cloud Project Repository (not from this sample repository)
    a. Call the copy `cloud.gitignore`
    b. place both files in the root of your repository
