# MeshKernelReleaseAutomation

This repository contains bash and python scripts for the the release automation of MeshKernel and its related products.

## Usage

It is assumed below that the release script is run from the root directory of the repository.

To display the usage, use

```bash
./scripts/automation/release.sh --help
```

Example

```bash
./scripts/automation/release.sh \
    <--work_dir /path/to/work/dir> \
    <--version VERSION> \
    <--start_point {main | master | latest | tag | branch | commit}> \
    <--github_access_token GITHUB_ACCESS_TOKEN> \
    [--github_refresh_interval GITHUB_REFRESH_INTERVAL=30] \
    [--delay DELAY=30] \
    [--upload_to_pypi] \
    [--pypi_access_token PYPI_ACCESS_TOKEN] \
    <--teamcity_access_token TEAMCITY_ACCESS_TOKEN> \
    [--clean]
```

When the optional switch `--upload_to_pypi` is provided, `--pypi_access_token` becomes mandatory.
