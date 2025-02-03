#!/bin/bash

function pin_and_tag_artifacts_MeshKernel() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    # pin the last MeshKernel build
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name NuGetContent.zip \
        --build_config_id GridEditor_MeshKernel${forked_repo_suffix}_Windows_Build \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
    # get the pinned build number
    local meshkernel_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_MeshKernel${forked_repo_suffix}_Windows_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    echo "Build number is ${meshkernel_build_number}"
    # pin the MeshKernel nupkg
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name Deltares.MeshKernel.${version}.${meshkernel_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernel${forked_repo_suffix}_Windows_NuGet_MeshKernelSigned \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
}

function pin_and_tag_artifacts_MeshKernelPy() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name meshkernel-${version}-py3-none-win_amd64.whl \
        --build_config_id GridEditor_MeshKernelPy${forked_repo_suffix}_Windows_BuildPythonWheel \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}

    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name meshkernel-${version}-py3-none-manylinux_2_28_x86_64.whl \
        --build_config_id GridEditor_MeshKernelPy${forked_repo_suffix}_Linux_BuildPythonWheel \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
}

function pin_and_tag_artifacts_MeshKernelNET() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    # pin the last MeshKernelNET build
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name output.zip \
        --build_config_id GridEditor_MeshKernelNet${forked_repo_suffix}_Build \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
    # get the pinned build number
    local meshkernelnet_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_MeshKernelNet${forked_repo_suffix}_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    # pin the MeshKernelNET nupkg
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name MeshKernelNET.${version}.${meshkernelnet_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernelNet${forked_repo_suffix}_NuGet_MeshKernelNETSigned \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
}

function pin_and_tag_artifacts_GridEditorPlugin() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    # pin the last GridEditorPlugin build
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name bin.zip \
        --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Build \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
    # get the pinned build number
    local grideditorplugin_nupkg_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    # pin the GridEditorPlugin nupkg
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name DeltaShell.Plugins.GridEditor.${version}.${grideditorplugin_nupkg_build_number}.nupkg \
        --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Deliverables_NuGetPackageSigned \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}

    # pin the GridEditorPlugin msi
    local grideditorplugin_msi_build_number=$(
        python ${scripts_path}/get_build_number.py \
            --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Deliverables_Installers_DGridEditorSignedMsiSInstallers \
            --version ${version} \
            --last_successful_build \
            --teamcity_access_token ${teamcity_access_token}
    )
    local msi_file_name="D-GridEditor ${dhydro_suite_version} (${grideditorplugin_msi_build_number}).msi"
    python ${scripts_path}/pin_artifact.py \
        --branch_name ${release_branch} \
        --build_config_id GridEditor_GridEditorPlugin${forked_repo_suffix}_Deliverables_Installers_DGridEditorSignedMsiSInstallers \
        --tag ${tag} \
        --artifact_path "installer/setup/GridEditor/bin/Release/stand-alone" \
        --artifact_name "${msi_file_name}" \
        --teamcity_access_token ${teamcity_access_token}
}
