#!/bin/bash

automatic_update_teamcity_config_ids=(
    "GridEditor_MeshKernelNet${forked_repo_suffix}_HelperConfigurations_AutomaticNugetPackageUpdates_UpdateDhydroSharedConfigurationNuGetPackage"
    "GridEditor_MeshKernelNet${forked_repo_suffix}_HelperConfigurations_AutomaticNugetPackageUpdates_UpdateMeshKernelNuGetPackage"
    "GridEditor_GridEditorPlugin${forked_repo_suffix}_HelperConfigurations_AutomaticNugetPackageUpdates_UpdateDeltaresNetNuGetPackages"
    "GridEditor_GridEditorPlugin${forked_repo_suffix}_HelperConfigurations_AutomaticNugetPackageUpdates_UpdateDeltaShellFrameworkNuGetPackages"
    "GridEditor_GridEditorPlugin${forked_repo_suffix}_HelperConfigurations_AutomaticNugetPackageUpdates_UpdateDhydroSharedConfigurationNuGetPackage"
    "GridEditor_GridEditorPlugin${forked_repo_suffix}_HelperConfigurations_AutomaticNugetPackageUpdates_UpdateMeshKernelNETNuGetPackage"
)

function pause_automatic_teamcity_updates() {
    show_progress
    for config_id in "${automatic_update_teamcity_config_ids[@]}"; do
        python $(get_scripts_path)/pause_teamcity_build_config.py \
            --build_config_id "${config_id}" \
            --pause \
            --teamcity_access_token ${teamcity_access_token}

    done
}

function resume_automatic_teamcity_updates() {
    show_progress
    for config_id in "${automatic_update_teamcity_config_ids[@]}"; do
        python $(get_scripts_path)/pause_teamcity_build_config.py \
            --build_config_id "${config_id}" \
            --resume \
            --teamcity_access_token ${teamcity_access_token}

    done
}
