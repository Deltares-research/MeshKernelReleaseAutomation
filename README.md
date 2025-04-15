# MeshKernelReleaseAutomation

This repository contains bash and python scripts for the the release automation of MeshKernel and its related products.

## Preparation

### Conventions

release_number: <major>.<minor>.<patch>
release_label: v<release_label>
release_branch: release/<release_label>

### One-time setup

#### Prerequisite software

Install

* wsl
* git
* python
* conda (miniconda)
* gh
* jq

Note on installing gh: sudo apt install gh installed an old version of gh. Following commands succeeded in installing the latest version.

   % type -p curl >/dev/null || sudo apt install curl -y
   % curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   % echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   % sudo apt update
   % sudo apt install gh -y
   % gh --version

Setup or copy your .gitconfig

#### Access tokens

Get access tokens for:
* teamcity
   on https://dpcbuild.deltares.nl/profile.html?item=accessTokens
   create token
   save token in file (make sure it contains just the token, no newline)

* github
   - on wsl: create new ssh key
     % ssh-keygen -t rsa -b 4096 -C "andreas.buykx@deltares.nl"
   - copy public key
   - goto https://github.com/settings/keys
   - create new SSH key
     create classic token
     scopes: repo, workflow, admin:org
   - paste the public key
   - authorize Deltares and Deltares-Research (under Configure SSO)

* pypi
   - create account (save recovery codes)
   - 2FA authentication with authenticator
   - create API token

* clone MeshKernelReleaseAutomation repository

## Prepare for installing

* start a wsl terminal
* setup a conda environment on WSL
   % . ~/setup_conda.sh
   % conda activate base

Two scenarios are supported:
1. release from master
2. patch release from prepared patch release branches

### Release from master

Run release script with --start_point master option

### Patch release

For each repository (MeshKernel, MeshKernelNET, MeshKernelPy,
GridEditor_Plugin) create a release branch.

Cherry-pick additional commits (use git cherry-pick -x <sha> to mention the original
commit sha in the commit message) where appropriate.

Push release branches to remote.

Run release script with --start_point <release_branch> option

### Post-script checks

#### TeamCity
* MeshKernel
  - pinned and tagged signed NuGet package
* MeshKernelNet
  - pinned and tagged signed NuGet package
* GridEditor
  - pinned and tagged D-Grid Editor Signed MSIs installer
  - pinned and tagged signed NuGet package
* MeshKernelPy
  - pinned and tagged python wheel both for linux and windows

### PyPI
New release available on https://pypi.org/project/meshkernel/

#### Github
* No open release pull requests on any repository
* release branch including release tag merged back to main

## Usage

It is assumed below that the release script is run from the root directory of the repository.

To display the usage, use

```bash
./scripts/automation/release.sh --help
```

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
| --work_dir                                | Required  | string    | Path to the work directory               | all repositories will be cloned in subdirectories of this directory.                          |
| --version                                 | Required  | string    | Semantic version of new release          | e.g. 7.0.0                                                                                    |
| <nobr>--release_grid_editor_plugin</nobr> | Optional  | -         | Grid Editor plugin release switch        | If supplied, Grid Editor plugin is released beside MeshKernel, MeshKernelPy and MeshKernelNET |
| --dhydro_suite_version                    | Dependent | string    | Version of D-HYDRO suite                 | Required if --release_grid_editor_plugin is provided, ignored otherwise                       |
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
