#!/bin/bash

function update_MeshKernel() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # bump version of backend
    local cmakelists_file=${work_dir}/${repo_name}/CMakeLists.txt
    python ${scripts_path}/bump_mk_version.py \
        --file ${cmakelists_file} \
        --to_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump version"
}

function update_MeshKernelPy() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # bump version of python bindings
    local python_version_file=${work_dir}/${repo_name}/meshkernel/version.py
    python ${scripts_path}/bump_mkpy_versions.py \
        --file ${python_version_file} \
        --to_version ${version} \
        --to_backend_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump versions of python bindings"
}

function update_MeshKernelNET() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # bump product version
    local nuspec_file=${work_dir}/${repo_name}/nuget/MeshKernelNET.nuspec
    local dir_build_props_file=${work_dir}/${repo_name}/Directory.Build.props
    python ${scripts_path}/bump_package_version.py \
        --nuspec_file ${nuspec_file} \
        --dir_build_props_file ${dir_build_props_file} \
        --version_tag "MeshKernelNETVersion" \
        --to_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump version"

    # bump versions of dependencies
    local meshkernel_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_MeshKernel${forked_repo_suffix}_Windows_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    local dir_package_props_file=${work_dir}/${repo_name}/Directory.Packages.props
    python ${scripts_path}/bump_dependencies_versions.py \
        --dir_packages_props_file ${dir_package_props_file} \
        --to_versioned_packages "Deltares.MeshKernel:${version}.${meshkernel_build_number}"
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump versions of dependencies"
}

function update_GridEditorPlugin() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # bump product version
    local nuspec_file=${work_dir}/${repo_name}/SDK/GridEditorDeltaShellPlugin.nuspec
    local dir_build_props_file=${work_dir}/${repo_name}/Directory.Build.props
    python ${scripts_path}/bump_package_version.py \
        --nuspec_file ${nuspec_file} \
        --dir_build_props_file ${dir_build_props_file} \
        --version_tag "GridEditorPluginFileVersion" \
        --to_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump version"

    # bump versions of dependencies
    local meshkernelnet_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_MeshKernelNet${forked_repo_suffix}_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    local dir_package_props_file=${work_dir}/${repo_name}/Directory.Packages.props
    python ${scripts_path}/bump_dependencies_versions.py \
        --dir_packages_props_file ${dir_package_props_file} \
        --to_versioned_packages "MeshKernelNET:${version}.${meshkernelnet_build_number}"
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump versions of dependencies"

    # bump msi versions
    local dir_wix_config=${work_dir}/${repo_name}/setup/GridEditor
    python ${scripts_path}//bump_gep_msi_version.py \
        --wix_ui_variables_file ${dir_wix_config}/WixUI/WixUIVariables.wxl \
        --wix_proj_file ${dir_wix_config}/GridEditor.wixproj \
        --to_release_version ${version}

    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: bump version of wix configuration"
}
