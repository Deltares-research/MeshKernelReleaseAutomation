# MeshKernelReleaseAutomation

This repository contains bash and python scripts for the release automation of MeshKernel and its related products.

## Preparation

### Conventions

release_number: <major>.<minor>.<patch>  
release_label: v<release_label>  
release_branch: release/<release_label>

### One-time setup

#### Prerequisite software

Install:

* wsl (or git bash on Windows, or use Linux directly – the scripts are standard bash)
* git
* python
* miniconda
* gh (GitHub CLI)
* jq (JSON processor)

#### Access tokens

Get access tokens for:

* **TeamCity**  
   - Visit https://dpcbuild.deltares.nl/profile.html?item=accessTokens  
   - Create token  
   - Save the token in a file (ensure it contains only the token, no newline)

* **GitHub**  
   - Visit https://github.com/settings/tokens
   - Generate a classic token with scopes: `repo`, `workflow`, `admin:org`.  
   - Save the token in a file
   - Authorize Deltares and Deltares-Research (under Configure SSO).   

* **PyPI**  
   - Create an account (save recovery codes).  
   - Enable 2FA with an authenticator.  
   - Create an API token with sufficient permissions to publish new releases.

* Clone the `MeshKernelReleaseAutomation` repository.

> **Important:** Before creating a release, ensure that **all TeamCity and GitHub pipelines are successful**. Any broken build will lead to release failure.

## Prepare for installing

Two scenarios are supported:
1. Release from `master`
2. Patch release from prepared patch release branches

### Release from master

Run the release script with the `--start_point master` option.

### Patch release

For each repository (MeshKernel, MeshKernelNET, MeshKernelPy, GridEditor_Plugin), create a release branch.

Cherry-pick additional commits (use `git cherry-pick -x <sha>` to mention the original commit sha in the commit message) where appropriate.

Push release branches to remote.

Run a release script with the `--start_point <release_branch>` option.

## Post-script checks

After the release script completes, perform the following checks:

### TeamCity
* MeshKernel  
  - pinned and tagged signed NuGet package
* MeshKernelNet  
  - pinned and tagged signed NuGet package
* GridEditor  
  - pinned and tagged D-Grid Editor Signed MSIs installer  
  - pinned and tagged signed NuGet package
* MeshKernelPy  
  - pinned and tagged Python wheel for Linux and Windows

### PyPI
* Verify that a new release is available on https://pypi.org/project/meshkernel/

### GitHub
* Verify that the desired release and tag have been created.
* Verify that all release assets were correctly uploaded.
* Ensure there are no open release pull requests on any repository.
* Verify that the release branch and tag have been merged back to main.

## Usage

It is assumed below that the release script is run from the root directory of the repository.

To display usage, run:

```bash
./scripts/automation/release.sh --help
```

Example usage:

```bash
./scripts/automation/release.sh \
    <--work_dir /path/to/work/dir> \
    <--version VERSION> \
    [--release_grid_editor_plugin] \
    <--start_point {main | master | latest | tag | branch | commit}> \
    [--auto_merge] \
    <--github_access_token GITHUB_ACCESS_TOKEN> \
    [--upload_to_pypi] \
    [--pypi_access_token PYPI_ACCESS_TOKEN] \
    <--teamcity_access_token TEAMCITY_ACCESS_TOKEN> \
    [--github_refresh_interval GITHUB_REFRESH_INTERVAL=30] \
    [--delay DELAY=30] \
    [--clean]
```

| Options                                   | Nature    | Data type | Description                              | Notes                                                                                         |
| ----------------------------------------- | --------- | --------- | ---------------------------------------- | --------------------------------------------------------------------------------------------- |
| --work_dir                                | Required  | string    | Path to the work directory               | all repositories will be cloned in subdirectories of this directory.                          |
| --version                                 | Required  | string    | Semantic version of new release          | e.g. 7.0.0                                                                                    |
| <nobr>--release_grid_editor_plugin</nobr> | Optional  | -         | Grid Editor plugin release switch        | If supplied, Grid Editor plugin is released beside MeshKernel, MeshKernelPy and MeshKernelNET |
| --start_point                             | Required  | string    | ID of commit, branch or tag to check out | If a branch is specified, the HEAD of the branch is checked out                               |
| --auto_merge                              | Optional  | -         | Auto-merge switch                        | If supplied, the release tag is merged into the base branch upon release creation             |
| --github_access_token                     | Required  | string    | Path to github access token              |                                                                                               |
| --upload_to_pypi                          | Optional  | -         | Upload to PyPi switch                    | If supplied, the generated python wheels are uploaded to PyPi                                 |
| --pypi_access_token                       | Dependent | string    | Path to PyPi access token                | Required if --upload_to_pypi is provided, ignored otherwise                                   |
| --teamcity_access_token                   | Required  | string    | Path to teamcity access token            | file must contain only token, without trailing newline                                        |
| --github_refresh_interval                 | Optional  | integer   | Refresh interval in seconds              | Used as a refresh interval while watching github PR checks (default = 30s)                    |
| --delay                                   | Optional  | integer   | Delay in seconds                         | The script sleeps for this duration before watching github PR checks (default = 30s)          |
| --clean                                   | Optional  | -         | Clean-up switch                          | If supplied, the work directory is removed upon completion                                    |
| --help                                    | Optional  | -         | Display the usage and exit               |                                                                                               |
