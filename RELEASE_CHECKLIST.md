# MeshKernel / Grid Editor release

## Introduction

This document describes the manual steps for releasing MeshKernel, MeshKernelNET, MeshKernelPy and, optionally, the Grid Editor plugin and standalone installer.

Create the release on separate release branches. Afterwards, merge the release changes back to each repository's default branch, or backport the applicable changes for a patch release.

Use one release version `X.Y.Z`, tag `vX.Y.Z` and branch `release/vX.Y.Z` across the participating repositories, following the release naming convention. NuGet packages also include a build counter; use their actual package versions when updating dependencies, not just `X.Y.Z`.

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
- [ ] If Grid Editor is included, review whether the user manual needs updates  for the changes in this release and arrange any required updates.
- [ ] Check that the relevant TeamCity builds and GitHub Actions macOS builds  pass. Resolve failures before proceeding.
- [ ] Make a list of expected release artifacts: 
  - 1 MeshKernel signed NuGet
  - 1 MeshKernelNET signed NuGet
  - 1 MeshKernelPy wheel file for Windows (amd64)
  - 1 MeshKernelPy wheel file for Linux (x86_64)
  - 2 MeshKernelPy wheel files for MacOS 15 (x86_64, arm64)
  - 1 MeshKernelPy wheel file for MacOS 26 (arm64)
  - (if applicable) 1 D-GridEditor signed MSI
  - (if applicable) 1 D-GridEditor plugin signed NuGet
- [ ] Create branch `release/vX.Y.Z` in each participating repository from its agreed starting revision and push it. For a patch release, start from the appropriate previous release and cherry-pick approved fixes.
- [ ] Open release pull requests targeting the repositories' default branches. Follow the repositories' PR naming conventions.
- [ ] When creating a new release from the default branch, for every repository check if the previous release tag is visible from the default branch. If not, special care must be taken when reviewing and publishing generated change information.

### MeshKernel

Steps:
- [ ] On the release branch, update the version number:
  - check out the release branch; 
  - set `MESHKERNEL_VERSION` to `X.Y.Z` in the root `CMakeLists.txt`
  - commit and push the changes.
- [ ] Wait for the Windows build (including NuGet packaging), Linux build and required checks on the release branch to pass.
- [ ] On TeamCity, pin and tag the Windows and Linux builds and the signed `Deltares.MeshKernel` NuGet build: 
  - check 'Apply to all snapshot dependencies'
  - name the pin and tag `vX.Y.Z`

Expected artifacts: Meshkernel signed NuGet

### MeshKernelNET

- [ ] On the release branch, update the version number and dependencies:
  - check out the release branch
  - set `MeshKernelNETVersion` to `X.Y.Z` in `Directory.Build.props`.
  - set the `Deltares.MeshKernel` package version in  `Directory.Packages.props` to the version of the signed NuGet package produced by the MeshKernel release build.
  - commit and push both the changes.
- [ ] Wait for the release-branch build, required checks and signed NuGet build to pass.
- [ ] On TeamCity, pin and tag the build containing `output.zip` and the signed  `MeshKernelNET` NuGet build:
  - check 'Apply to all snapshot dependencies'
  - name the pin and tag `vX.Y.Z` 

Expected artifacts: MeshKernelNET signed NuGet

### MeshKernelPy

- [ ] On the release branch, update the version number and dependencies:
  - set both `__version__` and `__backend_version__` to `X.Y.Z` in  `meshkernel\version.py`
  - commit and push the changes.
- [ ] Verify that the wheel builds use MeshKernel backend version `X.Y.Z`:
  - download the wheel; 
  - change the extension to zip; 
  - check the version information in meshkernel\version.py and meshkernel-X.Y.Z.dist-info\METADATA
- [ ] Wait for the Windows and Linux TeamCity wheel builds and the macOS GitHub Actions workflow `Build and test (release)` on the release branch and required pull request checks to pass.
- [ ] Pin and tag the Windows and Linux wheel builds:
  - check 'Apply to all snapshot dependencies'
  - name the pin and tag `vX.Y.Z` 

Expected artifacts: 5 MeshKernelPy wheel files

### Grid Editor (optional)

This entire section is not applicable for a libraries-only release.

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
- [ ] Pin and tag: 1) the build containing `bin.zip`, 2) the signed`DeltaShell.Plugins.GridEditor` NuGet build and 3) the signed standalone MSI build:
  - check 'Apply to all snapshot dependencies'
  - name the pin and tag `vX.Y.Z` 

Expected artifacts: 
- signed GridEditor NuGet
- signed D-GridEditor MSI

### Collect and publish

- [ ] Download all identified release artifacts from the recorded builds/runs. 
- [ ] Check names, versions and revisions against expected artifacts list; do not select artifacts merely because they are the newest. Use the actual MSI filename shown in TeamCity.
- [ ] Create and publish a GitHub release for each participating repository
  - see https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository
  - Draft a new release
  - use tag `vX.Y.Z` and target branch `release/vX.Y.Z`. 
  - ensure the tag points to the commit used to build the release artifacts. 
  - attach artifacts:
    - MeshKernel: signed NuGet
    - MeshKernelNet: signed NuGet
    - MeshKernelPy: Windows, Linux and macOS wheels
    - GridEditor: signed NuGet, signed standalone MSI
    GitHub automatically includes source archives (`.zip` and `.tar.gz`) for the release tag; these do not need to be uploaded separately.
  - review the release notes. These are auto-generated by github, see https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes. Select the appropriate `Previous tag`. If the previous release branch was not merged back to main it may be necessary to edit the release notes.   
  - Publish the releases once all assets are attached. 
  - Mark them as latest only when appropriate: an older maintenance release should not automatically replace a newer supported release.
- [ ] Upload the MeshKernelPy wheel files for Windows, Linux and macOS to PyPI using the approved publishing credentials/process:
  python -m twine upload --verbose --username __token__ --password <your_pypi_token> <downloaded_artifacts_folder>\*.whl

### Completion

- [ ] Have the release pull requests reviewed and approved before merging. For an older patch release, agree which changes should be backported instead of merging older version/dependency values into current development.
- [ ] Merge the approved release changes back into each repository's default branch, or backport the agreed changes for a patch release. Include all
  required version/dependency changes and any build-generated commits. Resolve conflicts deliberately and close the associated release PR with a merge commit, _not_ a squash-and-merge commit, to make sure that the history shows the double ancestry: the main branch and the release branch.
- [ ] Keep the `release/vX.Y.Z` branches after merging. Do not delete them through the pull requests; repository policy protects these branches.

### Post release checklist

- [ ] Confirm the required default-branch builds and checks pass after merging.
- [ ] All git repositories have a release version tag vX.Y.Z. For a 'latest' release, the tag should be reachable from the default branch, for a patch of an older release, the tag should exist on the release branch
- [ ] All git repositories have a merge commit from the release branch back to the default branch. Note that if this is not 
- [ ] All TeamCity release artifacts are pinned and tagged with vX.Y.Z
- [ ] If the release produced a new latest/highest release number, version indicators in the default branch are updated as appropriate :
  - MeshKernel CMakeLists.txt : MESHKERNEL_VERSION 
  - MeshKernelNet Directory.Build.Props : MeshKernelNETVersion
  - MeshKernelNet Directory.Packages.Props : Deltares.MeshKernel package version
  - MeshKernelPy : version.py
  - GridEditor Directory.Build.Props : GridEditorPluginFileVersion
  - GridEditor Directory.Packages.Props : MeshKernelNET package version
  - GridEditor SDK\GridEditorDeltaShellPlugin.nuspec : package metadata version
  - GridEditor setup\WixUIVariables.wxl : ReleaseVersion
  
