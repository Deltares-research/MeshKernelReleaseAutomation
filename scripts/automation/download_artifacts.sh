#!/bin/bash

function download_python_wheels() {
    show_progress
    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    mkdir -p ${work_dir}/artifacts
    local python_wheels_dir=${work_dir}/artifacts/python_wheels
    mkdir -p ${python_wheels_dir}

    # TeamCity wheels
    local -A teamcity_build_configs
    teamcity_build_configs=(
        ["Windows"]="win_amd64"
        ["Linux"]="manylinux_2_28_x86_64"
    )
    for platform in "${!teamcity_build_configs[@]}"; do
        local arch=${teamcity_build_configs[${platform}]}
        python ${scripts_path}/download_teamcity_artifact.py \
            --branch_name ${release_branch} \
            --artifact_name meshkernel-${version}-py3-none-${arch}.whl \
            --build_config_id GridEditor_MeshKernelPy${forked_repo_suffix}_${platform}_BuildPythonWheel \
            --tag ${tag} \
            --destination ${python_wheels_dir} \
            --teamcity_access_token ${teamcity_access_token}
    done

    # Github wheels
    local repo=$(get_gh_repo_path ${repo_name_MeshKernelPy})
    local last_run_id=$(
        gh run list \
            --repo ${repo} \
            --workflow "Build and test (release)" \
            --branch=${release_branch} \
            --limit=1 \
            --json databaseId \
            --jq '.[].databaseId'
    )
    gh run download $last_run_id \
        --repo ${repo} \
        --pattern meshkernel-macos-*-Release \
        --dir ${python_wheels_dir}
    # move the wheels from the ${python_wheels_dir}/meshkernel-macos-* to ${python_wheels_dir}
    find ${python_wheels_dir} \
        -type d \
        -name 'meshkernel-macos-*-Release' \
        -exec sh -c 'mv "$1"/*.whl "$0"' "$python_wheels_dir" {} \;
    # then remove the unnecessary folders
    rm -fr ${python_wheels_dir}/meshkernel-macos-*
}

function download_nuget_packages() {
    show_progress
    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    mkdir -p ${work_dir}/artifacts
    local nuget_packages_dir=${work_dir}/artifacts/nuget_packages
    mkdir -p ${nuget_packages_dir}

    # MeshKernel
    local meshkernel_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_MeshKernel${forked_repo_suffix}_Windows_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    python ${scripts_path}/download_teamcity_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name Deltares.MeshKernel.${version}.${meshkernel_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernel${forked_repo_suffix}_Windows_NuGet_MeshKernelSigned \
        --tag ${tag} \
        --destination ${nuget_packages_dir} \
        --teamcity_access_token ${teamcity_access_token}

    # MeshKernelNET
    local meshkernelnet_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_MeshKernelNet${forked_repo_suffix}_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    python ${scripts_path}/download_teamcity_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name MeshKernelNET.${version}.${meshkernelnet_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernelNet${forked_repo_suffix}_NuGet_MeshKernelNETSigned \
        --tag ${tag} \
        --destination ${nuget_packages_dir} \
        --teamcity_access_token ${teamcity_access_token}

    # GridEditorPlugin
    if ${release_grid_editor_plugin}; then
        local grideditorplugin_build_number=$(
            python ${scripts_path}/get_build_number.py \
                --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Build \
                --version ${version} \
                --teamcity_access_token ${teamcity_access_token}
        )
        python ${scripts_path}/download_teamcity_artifact.py \
            --branch_name ${release_branch} \
            --artifact_name DeltaShell.Plugins.GridEditor.${version}.${grideditorplugin_build_number}.nupkg \
            --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Deliverables_NuGetPackageSigned \
            --tag ${tag} \
            --destination ${nuget_packages_dir} \
            --teamcity_access_token ${teamcity_access_token}
    fi
}

function download_msi() {
    show_progress
    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    mkdir -p ${work_dir}/artifacts
    local msi_dir=${work_dir}/artifacts/msi
    mkdir -p ${msi_dir}

    # GridEditorPlugin
    if ${release_grid_editor_plugin}; then
        local build_config_id="GridEditor_GridEditorPlugin${forked_repo_suffix}_Deliverables_Installers_CreateMsiWithSignedDllS"
        local grideditorplugin_build_number=$(
            python ${scripts_path}/get_build_number.py \
                --build_config_id ${build_config_id} \
                --version ${version} \
                --teamcity_access_token ${teamcity_access_token}
        )

        local msi_file_name="D-Grid Editor ${dhydro_suite_version} (${grideditorplugin_build_number}).msi"

        python ${scripts_path}/download_teamcity_artifact.py \
            --branch_name ${release_branch} \
            --artifact_path "installer/setup/GridEditor/bin/Release/stand-alone" \
            --artifact_name "${msi_file_name}" \
            --build_config_id ${build_config_id} \
            --tag ${tag} \
            --destination ${msi_dir} \
            --teamcity_access_token ${teamcity_access_token}
    fi
}
