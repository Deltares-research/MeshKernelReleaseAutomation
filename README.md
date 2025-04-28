# MeshKernelReleaseAutomation

This repository contains bash and python scripts for the the release automation of MeshKernel and its related products.

## Usage

It is assumed below that the release script is run from the root directory of the repository.
It is also assumed that Miniconda or Anaconda is installed on your Linux distribution.

To display the usage, use

```bash
./scripts/automation/release.sh --help
```
The file `./scripts/globals.sh` contains global variables used across all scripts. To work with test branches 
and simulate a release, set the `repo_owner` and `forked_repo_suffix` variables as follows:

```bash
declare -g repo_owner="Deltares-research"
declare -g forked_repo_suffix="Test"
```
To work with production branches, set the `repo_owner` and `forked_repo_suffix` variables as follows:
```bash
declare -g repo_owner="Deltares"
declare -g forked_repo_suffix=""
```
The scripts clone Git repositories using SSH. To use SSH with `git clone`, you must set up SSH keys in your 
GitHub account under **Settings** > **SSH and GPG keys**. 
Additionally, Single Sign-On (SSO) must be configured for the key to authorize the Deltares and Deltares-Research organizations.

GitHub tokens can be managed under **GitHub account** > **Developer settings** > **Personal access tokens** (classic). When generating a new token, ensure that SSO is configured to authorize Deltares and Deltares-Research.


Usage:

```bash
./scripts/automation/release.sh \
    <--work_dir /path/to/work/dir> \
    <--version VERSION> \
    [--release_grid_editor_plugin] \
    <--dhydro_suite_version DHYDRO_SUITE_VERSION> \
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
| --work_dir                                | Required  | string    | Path to the work directory               |                                                                                               |
| --version                                 | Required  | string    | Semantic version of new release          |                                                                                               |
| <nobr>--release_grid_editor_plugin</nobr> | Optional  | -         | Grid Editor plugin release switch        | If supplied, Grid Editor plugin is released beside MeshKernel, MeshKernelPy and MeshKernelNET |
| --dhydro_suite_version                    | Dependent | string    | Version of D-HYDRO suite                 | Required if --release_grid_editor_plugin is provided, ignored otherwise                       |
| --start_point                             | Required  | string    | ID of commit, branch or tag to check out | If a branch is specified, the HEAD of the branch is checked out                               |
| --auto_merge                              | Optional  | -         | Auto-merge switch                        | If supplied, the release tag is merged into the base branch upon release creation             |
| --github_access_token                     | Required  | string    | Path to github access token              |                                                                                               |
| --upload_to_pypi                          | Optional  | -         | Upload to PyPi switch                    | If supplied, the generated python wheels are uploaded to PyPi                                 |
| --pypi_access_token                       | Dependent | string    | Path to PyPi access token                | Required if --upload_to_pypi is provided, ignored otherwise                                   |
| --teamcity_access_token                   | Required  | string    | Path to teamcity access token            |                                                                                               |
| --github_refresh_interval                 | Optional  | integer   | Refresh interval in seconds              | Used as a refresh interval while watching github PR checks (default = 30s)                    |
| --delay                                   | Optional  | integer   | Delay in seconds                         | The script sleeps for this duration before watching github PR checks (default = 30s)          |
| --clean                                   | Optional  | -         | Clean-up switch                          | If supplied, the work directory is removed upon completion                                    |
| --help                                    | Optional  | -         | Display the usage and exit               |                                                                                               |
