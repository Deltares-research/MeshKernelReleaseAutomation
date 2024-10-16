#!/bin/bash

set -e

declare -g scripts_path=$(dirname $(realpath "$0"))

source ${scripts_path}/globals.sh
source ${scripts_path}/utilities.sh
source ${scripts_path}/catch.sh
source ${scripts_path}/usage.sh
source ${scripts_path}/parse_arguments.sh
source ${scripts_path}/work_dir.sh
source ${scripts_path}/conda_env.sh
source ${scripts_path}/github.sh
source ${scripts_path}/monitor_checks_on_branch.sh
source ${scripts_path}/pause_teamcity_auto_updates.sh
source ${scripts_path}/update_repositories.sh
source ${scripts_path}/pin_and_tag_artifacts.sh
source ${scripts_path}/download_artifacts.sh
source ${scripts_path}/upload_artifacts.sh

function release() {
    show_progress

    local product=$1
    local repo_name=$2

    print_text_box "${repo_name} Release v${version}"

    local tag=v${version}

    if (release_exists_and_is_latest ${repo_name} ${tag}); then
        echo "Release tagged as ${tag} exists and is set as latest. Skipping."
    else
        local release_branch=release/${tag}
        clone ${repo_name}
        check_start_point ${repo_name} ${start_point}
        check_tag ${repo_name} ${tag}
        validate_new_version ${repo_name} ${version}
        create_release_branch ${repo_name} ${release_branch} ${start_point}
        update_${product} ${repo_name} ${release_branch}
        create_pull_request ${repo_name} ${release_branch} ${tag}
        monitor_pull_request_checks ${repo_name} ${release_branch}
        create_release ${repo_name} ${release_branch} ${tag}
        pin_and_tag_artifacts_${product} ${release_branch} ${version} ${tag} ${teamcity_access_token}
        if ${auto_merge}; then
            merge_release_tag_into_base_branch ${repo_name} ${tag}
            monitor_checks_on_base_branch ${repo_name}
        else
            col_echo --green "Warning: auto-merge is disabled. You must merge the release tag or cherry-pick all new commits (including automatic commits) manually to the default branch."
        fi
    fi
}

function main() {

    local start_time=$(date +%s)

    parse_arguments "$@"
    check_arguments

    print_text_box "Release v${version}"

    log_in

    create_work_dir

    local tag=v${version}
    local release_branch=release/${tag}

    create_conda_env ${scripts_path}/conda_env.yml

    pause_automatic_teamcity_updates

    release "MeshKernel" ${repo_name_MeshKernel}
    release "MeshKernelPy" ${repo_name_MeshKernelPy}
    release "MeshKernelNET" ${repo_name_MeshKernelNET}
    if ${release_grid_editor_plugin}; then
        release "GridEditorPlugin" ${repo_name_GridEditorPlugin}
    fi

    resume_automatic_teamcity_updates

    download_python_wheels ${release_branch} ${version} ${tag} ${teamcity_access_token}
    download_nuget_packages ${release_branch} ${version} ${tag} ${teamcity_access_token}
    download_msi ${release_branch} ${version} ${tag} ${teamcity_access_token}

    upload_python_wheels_to_github ${tag}
    upload_nuget_packages_to_github ${tag}
    upload_msi_to_github ${tag}
    if ${upload_to_pypi}; then
        upload_python_wheels_to_pypi ${pypi_access_token}
    fi

    remove_conda_env

    remove_work_dir

    log_out

    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    print_text_box "Release v${version} took $(date -u -d "@$elapsed_time" +%H:%M:%S)"
}

main "$@"
