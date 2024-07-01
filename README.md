# MeshKernelReleaseAutomation

This repository contains bash and python scripts for the the release automation of MeshKernel and its related products.

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
    <--dhydro_suite_version DHYDRO_SUITE_VERSION>
    <--start_point {main | master | latest | tag | branch | commit}> \
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
| --github_access_token                     | Required  | string    | Path to github access token              |                                                                                               |
| --upload_to_pypi                          | Optional  | -         | Upload to PyPi switch                    | If supplied, the generated python wheels are uploaded to PyPi                                 |
| --pypi_access_token                       | Dependent | string    | Path to PyPi access token                | Required if --upload_to_pypi is provided, ignored otherwise                                   |
| --teamcity_access_token                   | Required  | string    | Path to teamcity access token            |                                                                                               |
| --github_refresh_interval                 | Optional  | integer   | Refresh interval in seconds              | Used as a refresh interval while watching github PR checks (default = 30s)                    |
| --delay                                   | Optional  | integer   | Delay in seconds                         | The script sleeps for this duration before watching github PR checks (default = 30s)          |
| --clean                                   | Optional  | -         | Clean-up switch                          | If supplied, the work directory is removed upon completion                                    |
| --help                                    | Optional  | -         | Display the usage and exit               |                                                                                               |
