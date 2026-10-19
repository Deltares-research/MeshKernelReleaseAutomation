# MeshKernel / Grid Editor release

## Introduction

This document describes the manual steps for releasing MeshKernel, MeshKernelNET, MeshKernelPy and, optionally, the Grid Editor plugin and standalone installer.

Create the release on separate release branches. Afterwards, merge the release
changes back to each repository's default branch, or backport the applicable
changes for a patch release.

Use one release version `X.Y.Z`, tag `vX.Y.Z` and branch `release/vX.Y.Z`
across the participating repositories, following the release naming convention.
NuGet packages also include a build counter; use their actual package versions
when updating dependencies, not just `X.Y.Z`.

| Product | GitHub repository | TeamCity project |
| --- | --- | --- |
| MeshKernel | [Deltares/MeshKernel](https://github.com/Deltares/MeshKernel) | [Deltares Mesh Generator/GridEditor_MeshKernel](https://dpcbuild.deltares.nl/project/GridEditor_MeshKernel) |
| MeshKernelNET | [Deltares/MeshKernelNET](https://github.com/Deltares/MeshKernelNET) | [Deltares Mesh Generator/MeshKernelNET](https://dpcbuild.deltares.nl/project/GridEditor_MeshKernelNet) |
| MeshKernelPy | [Deltares/MeshKernelPy](https://github.com/Deltares/MeshKernelPy) | [Deltares Mesh Generator/MeshKernelPy](https://dpcbuild.deltares.nl/project/GridEditor_MeshKernelPy) |
| Grid Editor | [Deltares/Grid_Editor_plugin](https://github.com/Deltares/Grid_Editor_plugin) | [Deltares Mesh Generator/GridEditor_GridEditorPlugin](https://dpcbuild.deltares.nl/project/GridEditor_GridEditorPlugin) |


MeshKernelPy macOS wheels are available as artifacts of the GitHub Actions
[Build and test (release)](https://github.com/Deltares/MeshKernelPy/actions/workflows/build-and-test-release.yml)
workflow.

## Release checklist

Follow the steps below for each component included in the release. Use
successful builds from the release branches and verify that their versions
and dependencies match the intended release. Download the release artifacts
from these builds for publication on GitHub and PyPI.

### Preparation

- [ ] Agree on the release version. Decide whether this is the latest supported
  release or a patch of an older release.
- [ ] If Grid Editor is included, review whether the user manual needs updates
  for the changes in this release and arrange any required updates.
- [ ] Check that the relevant TeamCity builds and GitHub Actions macOS builds
  pass. Resolve failures before proceeding.
- [ ] Create `release/vX.Y.Z` in each participating repository from its agreed
  starting revision and push it. For a patch release, start from the appropriate
  previous release and cherry-pick approved fixes.
- [ ] Open release pull requests targeting the repositories' default branches. Follow the repositories' PR naming conventions.

### MeshKernel

- [ ] Set `MESHKERNEL_VERSION` to `X.Y.Z` in the root `CMakeLists.txt`; commit
  and push the change to the release branch.
- [ ] Wait for the Windows build (including NuGet packaging), Linux build
  and required checks on the release branch to pass.
- [ ] Pin and tag the Windows and Linux builds and the signed
  `Deltares.MeshKernel` NuGet build with `vX.Y.Z`.

### MeshKernelNET

- [ ] Set `MeshKernelNETVersion` to `X.Y.Z` in `Directory.Build.props`.
- [ ] Set the `Deltares.MeshKernel` package version in
  `Directory.Packages.props` to the version of the signed NuGet package produced
  by the MeshKernel release build.
  Commit and push both version changes.
- [ ] Wait for the release-branch build, required checks and signed NuGet build
  to pass.
- [ ] Pin and tag the build containing `output.zip` and the signed
  `MeshKernelNET` NuGet build with `vX.Y.Z`.

### MeshKernelPy

- [ ] Set both `__version__` and `__backend_version__` to `X.Y.Z` in
  `meshkernel\version.py`; commit and push the changes.
- [ ] Verify that the wheel builds use MeshKernel backend version `X.Y.Z`.
- [ ] Wait for the Windows and Linux TeamCity wheel builds and the macOS
  GitHub Actions workflow `Build and test (release)` on the release branch
  and required pull request checks to pass.
- [ ] Pin and tag the Windows and Linux wheel builds with `vX.Y.Z`.


### Grid Editor (optional)

Mark this entire section as not applicable for a libraries-only release.

- [ ] Set `GridEditorPluginFileVersion` to `X.Y.Z` in `Directory.Build.props`
  and the package metadata version to `X.Y.Z` in
  `SDK\GridEditorDeltaShellPlugin.nuspec`.
- [ ] Set the `MeshKernelNET` package version in `Directory.Packages.props`
  to the version of the signed NuGet package produced by the MeshKernelNET
  release build.
- [ ] Set the `ReleaseVersion` string's `Value` to `X.Y.Z` in
  `setup\WixUIVariables.wxl`.
- [ ] Update the Grid Editor user manual at
  `setup\GridEditor\Resources\GridEditor_User_Manual.pdf` if required.
- [ ] Commit and push all version and manual changes to the release branch.
- [ ] Wait for the release-branch build, required checks, signed NuGet package
  and signed standalone MSI build to pass.
- [ ] Pin and tag the build containing `bin.zip`, the signed
  `DeltaShell.Plugins.GridEditor` NuGet build and the signed standalone MSI
  build with `vX.Y.Z`.

### Collect and publish

- [ ] Download the signed NuGet packages, Python wheels and, if
  applicable, signed MSI from the recorded builds/runs. Check versions and
  revisions; do not select artifacts merely because they are the newest.
  Use the actual MSI filename shown in TeamCity.
- [ ] Create and publish a GitHub release for each participating repository with tag
  `vX.Y.Z` and target branch `release/vX.Y.Z`. Ensure the tag points to the
  commit used to build the release artifacts. Prepare it as a draft and attach
  the signed NuGet packages to their respective MeshKernel and MeshKernelNET
  releases, the Windows, Linux and macOS wheels to MeshKernelPy, and both the
  signed plugin NuGet package and standalone MSI to Grid Editor.
  GitHub automatically includes source archives (`.zip` and `.tar.gz`) for
  the release tag; these do not need to be uploaded separately.
  Publish the releases once all assets are attached. Mark them as latest only when
  appropriate; an older maintenance release should not automatically replace
  a newer supported release.
- [ ] Upload the MeshKernelPy Python wheels for Windows, Linux and macOS to
  PyPI using the approved publishing credentials/process.

### Completion

- [ ] Have the release pull requests reviewed and approved before merging. For an
  older patch release, agree which changes should be backported instead of
  merging older version/dependency values into current development.
- [ ] Merge the approved release changes back into each repository's default
  branch, or backport the agreed changes for a patch release. Include all
  required version/dependency changes and any build-generated commits. Resolve
  conflicts deliberately and close the associated release PRs.
- [ ] Keep the `release/vX.Y.Z` branches after merging. Do not delete them
  through the pull requests; repository policy protects these branches.
- [ ] Confirm the required default-branch builds and checks pass after merging.