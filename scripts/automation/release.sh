#!/bin/bash

set -e

repo_host=github.com
repo_owner=Deltares-research

github_refresh_interval=30 # seconds
delay=${github_refresh_interval}
upload_to_pypi=false
pypi_access_token=""
teamcity_access_token=""
clean=false

function col_echo() {
    local color=$1
    local text=$2
    if ! [[ ${color} =~ '^[0-9]$' ]]; then
        case $(echo ${color} | tr '[:upper:]' '[:lower:]') in
        --black | -k)
            color=0
            ;;
        --red | -r)
            color=1
            ;;
        --green | -g)
            color=2
            ;;
        --yellow | -y)
            color=3
            ;;
        --blue | -b)
            color=4
            ;;
        --magenta | -m)
            color=5
            ;;
        --cyan | -c)
            color=6
            ;;
        --white | -w)
            color=7
            ;;
        *) # default color
            color=9
            ;;
        esac
    fi
    tput setaf ${color}
    echo ${text}
    tput sgr0
}

function show_progress() {
    col_echo --blue ">> Executing: ${FUNCNAME[1]}"
}

function catch() {
    local exit_code=$1
    if [ ${exit_code} != "0" ]; then
        col_echo --red "Error occurred"
        col_echo --red "  Line     : ${BASH_LINENO[1]}"
        col_echo --red "  Function : ${FUNCNAME[1]}"
        col_echo --red "  Command  : ${BASH_COMMAND}"
        col_echo --red "  Exit code: ${exit_code}"
    fi
}

trap 'catch $?' EXIT

function usage {
    echo "Usage: $0 [OPTIONS]"
    echo "Creates a new release."
    echo " Options:"
    echo "  --work_dir                 Required   string   Path to the work directory"
    echo "  --version                  Required   string   Semantic version of new release"
    echo "  --start_point              Required   string   ID of commit, branch or tag to check out"
    echo "                                                 If a branch is specified, the HEAD of the branch is checked out"
    echo "  --github_access_token      Required   string   Path to github access token"
    echo "  --github_refresh_interval  Optional   integer  Refresh interval in seconds."
    echo "  --upload_to_pypi           Optional            If supplied, the python wheels are uploaded to PyPi"
    echo "  --pypi_access_token        Dependent  string   Path to PyPi access token"
    echo "                                                 Required if --upload_to_pypi is provided, ignored otherwise"
    echo "  --teamcity_access_token    Dependent  string   Path to teamcity access token"
    echo "                                                 Required if --upload_to_pypi is provided, ignored otherwise"
    echo "                                                 Used as a refresh interval while watching github PR checks (default = 30s)"
    echo "  --delay                    Optional   integer  Delay in seconds"
    echo "                                                 The script sleeps for this duration before watching github PR checks (default = 30s)"
    echo "  --clean                    Optional            If supplied, the work directory is removed upon completion"
    echo "  --help                                         Display this help and exit"
    echo ""
}

# Define the parse_named_arguments function
function parse_arguments() {
    show_progress
    local do_exit=false
    positional_args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
        --help)
            usage
            exit 0
            ;;
        --work_dir)
            declare -g work_dir="$2"
            shift # past argument
            shift # past value
            ;;
        --version)
            declare -g version="$2"
            shift # past argument
            shift # past value
            ;;
        --start_point)
            declare -g start_point="$2"
            shift # past argument
            shift # past value
            ;;
        --github_access_token)
            declare -g github_access_token="$2"
            shift # past argument
            shift # past value
            ;;
        --github_refresh_interval)
            declare -gi github_refresh_interval="$2"
            shift # past argument
            shift # past value
            ;;
        --upload_to_pypi)
            declare -g upload_to_pypi=true
            shift # past argument
            ;;
        --pypi_access_token)
            declare -g pypi_access_token="$2"
            shift # past argument
            shift # past value
            ;;
        --teamcity_access_token)
            declare -g teamcity_access_token="$2"
            shift # past argument
            shift # past value
            ;;
        --delay)
            declare -gi delay="$2"
            shift # past argument
            shift # past value
            ;;
        --clean)
            declare -g clean=true
            shift # past argument
            ;;
        -* | --*)
            echo "Unknown parameter $1"
            #usage
            #exit 1
            do_exit=true
            shift # past argument
            ;;
        *)
            positional_args+=("$1") # save positional arg
            shift                   # past argument
            ;;
        esac
    done

    # required parameters
    if [[ -z ${work_dir} ]]; then
        echo "Missing parameter --work_dir"
        do_exit=true
    elif [[ -z ${version} ]]; then
        echo "Missing parameter --version"
        do_exit=true
    elif [[ -z ${start_point} ]]; then
        echo "Missing parameter --start_point"
        do_exit=true
    elif [[ -z ${github_access_token} ]]; then
        echo "Missing parameter --github_access_token"
        do_exit=true
    fi

    # dependent parameters
    if ${upload_to_pypi}; then
        if ! test -f "${pypi_access_token}"; then
            echo "Missing parameter --pypi_access_token: required when --upload_to_pypi is provided."
            do_exit=true
        fi
        if ! test -f "${teamcity_access_token}"; then
            echo "Missing parameter --teamcity_access_token: required when --upload_to_pypi is provided."
            do_exit=true
        fi
    fi

    # positional arguments
    if ((${#positional_args[@]})); then
        echo "Found positional arguments (${positional_args[@]}). Such arguments are not allowed. Only named arguments are valid."
        do_exit=true
    fi

    if ${do_exit}; then
        usage
        exit 1
    fi
}

function log_in() {
    show_progress
    gh auth login --with-token <${github_access_token}
}

function log_out() {
    show_progress
    gh auth logout
}

function create_work_dir() {
    show_progress
    mkdir ${work_dir}
}

function remove_work_dir() {
    show_progress
    if ${clean}; then
        rm -fr ${work_dir}
    fi
}

function get_scripts_path() {
    echo $(dirname $(realpath "$0"))
}

function get_gh_repo_path() {
    local repo_name=$1
    echo ${repo_host}/${repo_owner}/${repo_name}
}

function get_local_repo_path() {
    local repo_name=$1
    echo ${work_dir}/${repo_name}
}

function clone() {
    show_progress
    local repo_url=git@${repo_host}:${repo_owner}/$1.git
    local destination=${work_dir}/$1
    git clone ${repo_url} ${destination}
}

function check_version_string() {
    local version=$1
    local pattern="^[0-9]+\.[0-9]+\.[0-9]+$"
    if ! [[ $version =~ $pattern ]]; then
        echo "The string \"$version\" does not correspond to a semantic version of the form <major>.<minor>.<patch>."
        return 1
    fi
    return 0
}

function check_time_value() {
    local name=$1
    local value=$2
    if [[ $2 -le 0 ]]; then
        echo "$1 must be a positive integer."
        return 1
    fi
    return 0
}

function check_start_point() {
    show_progress
    local repo_name=$1
    local repo_path=$(get_local_repo_path ${repo_name})
    # determine the nature of the starting point
    #local start_point=$2
    start_point=$2
    if [ "$start_point" == "main" ] ||
        [ "$start_point" == "master" ] ||
        [ "$start_point" == "latest" ]; then # auto-detects default branch name when there's a mess of mains and masters
        start_point=$(get_default_branch_name ${repo_name})
    elif (git -C ${repo_path} show-ref --tags --verify --quiet -- refs/tags/${start_point} >/dev/null 2>&1); then
        echo Starting point is ${start_point}, which is a tag.
    elif (git -C ${repo_path} show-ref --verify --quiet -- refs/heads/${start_point} >/dev/null 2>&1); then
        echo Starting point is ${start_point}, which is a branch.
    elif (git -C ${repo_path} rev-parse --verify ${start_point}^{commit} >/dev/null 2>&1); then
        echo Starting point is ${start_point}, which is a commit.
    else
        echo ${start_point} is neither a commit ID, a tag, nor a branch.
        return 1
    fi
    return 0
}

function check_tag() {
    local repo_name=$1
    local tag=$2
    local repo_path=$(get_local_repo_path ${repo_name})
    if (git -C ${repo_path} ls-remote --exit-code --tags origin ${tag} >/dev/null 2>&1); then
        echo "Tag ${tag} exists. Verify that the new version is correct."
        return 1
    fi
    return 0
}

function validate_new_version() {
    show_progress
    local repo_name=$1
    local new_version_string=$2

    check_version_string ${new_version_string}

    # extract the latest version string from the latest tag
    local repo_path=$(get_local_repo_path ${repo_name})
    local latest_version_tag=$(git -C ${repo_path} describe --tags $(git -C ${repo_path} rev-list --tags --max-count=1))
    local latest_version_string=${latest_version_tag#*v}
    check_version_string ${latest_version_string}

    # Split the latest and new version strings into arrays containing major, minor and patch versions
    IFS='.'
    read -ra latest_version_array <<<"${latest_version_string}"
    read -ra new_version_array <<<"${new_version_string}"
    unset IFS

    # Compare each segment
    for ((i = 0; i < 3; i++)); do
        local new_version_segment=${new_version_array[i]}
        local latest_version_segment=${latest_version_array[i]}
        if ((${new_version_segment} > ${latest_version_segment})); then
            return 0
        elif ((${new_version_segment} < ${latest_version_segment})); then
            echo "Cannot upgrade to specified version: new version (${new_version_string}) < latest version (${latest_version_string})"
            return 1
        fi
    done

    # Versions are equal
    echo "Cannot upgrade to specified version: new version = latest version (${latest_version_string})"
    return 1
}

function create_release_branch() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local start_point=$3
    local repo_path=$(get_local_repo_path ${repo_name})
    # pull remote
    git -C ${repo_path} pull origin ${start_point}
    git -C ${repo_path} status
    # switch to release branch
    git -C ${repo_path} checkout -B ${release_branch} ${start_point}
    git -C ${repo_path} status
    # and immediately push it to remote
    git -C ${repo_path} push -f origin ${release_branch}
    git -C ${repo_path} status
}

function get_default_branch_name() {
    local repo_name=$1
    local repo_path=$(get_local_repo_path ${repo_name})
    echo $(git -C ${repo_path} symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
}

function on_branch() {
    local repo_name=$1
    local branch=$2
    local repo_path=$(get_local_repo_path ${repo_name})
    local current_branch=$(git -C ${repo_path} rev-parse --abbrev-ref HEAD)
    if [ "${branch}" == "${current_branch}" ]; then
        return 0
    else
        return 1
    fi
}

function commit_and_push_changes() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local message=$3

    if ! (on_branch ${repo_name} ${release_branch}); then return 1; fi
    local repo_path=$(get_local_repo_path ${repo_name})
    # stage changes (brute force, maybe too much)
    git -C ${repo_path} add --all
    git -C ${repo_path} status
    # commit changes
    git -C ${repo_path} commit -m "$message"
    git -C ${repo_path} status
    # push changes to remote
    git -C ${repo_path} push -u origin ${release_branch}
    git -C ${repo_path} status
}

# function branch_has_new_commits() {
#     local repo_name=$1
#     local release_branch=$2

#     if ! (on_branch ${repo_name} ${release_branch}); then return 1; fi
#     local repo_path=$(get_local_repo_path ${repo_name})

#     # Get the hash of the branch's initial commit
#     local initial_commit_hash=$(git -C ${repo_path} rev-list --max-parents=0 HEAD)
#     # get the hash of the last commit
#     local last_commit_hash=$(git -C ${repo_path} rev-parse HEAD)

#     # Compare the commit hashes
#     if [ "${initial_commit_hash}" != "${last_commit_hash}" ]; then
#         return 0
#     fi
#     return 1
# }

function branch_has_new_commits() {
    show_progress
    local repo_name=$1
    local start_point=$2
    local release_branch=$3
    local repo_path=$(get_local_repo_path ${repo_name})
    # is this really te best way?
    echo "Checking if ${release_branch} has new commits on top of ${start_point}..."
    if [ -n "$(git -C ${repo_path} log --oneline ${start_point}..${release_branch})" ]; then
        echo "Found new commits"
        return 0
    else
        echo "Could not find new commits"
        return 1
    fi
}

function pull_request_exists() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo=$(get_gh_repo_path ${repo_name})
    # searching the list of open PRs does not return non-zero value if the search fails
    # gh pr list --state open --search ${release_branch} >/dev/null 2>&1; echo $? # prints 0
    # viewing an non-existent PR on the other hand does fail
    gh pr view ${release_branch} --repo ${repo} >/dev/null 2>&1
}

function create_pull_request() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local tag=$3
    # do it only if new commits have been pushed to the branch
    # (avoids non-zero exist code from gh pr create)
    if (branch_has_new_commits ${repo_name} ${start_point} ${release_branch}); then
        #if (branch_has_new_commits ${repo_name} ${start_point} ${release_branch}) &&
        #    ! (pull_request_exists ${repo_name} ${release_branch}); then
        local repo=$(get_gh_repo_path ${repo_name})
        # different repos have different default branch names, such as master or main
        local base_branch=$(get_default_branch_name ${repo_name})
        # create pull request
        gh pr create \
            --repo ${repo} \
            --base ${base_branch} \
            --head ${release_branch} \
            --title "Release ${tag}" \
            --body "Release ${tag}"
    # for some reason --fill does  not work
    fi
}

function monitor_checks() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo=$(get_gh_repo_path ${repo_name})
    if (pull_request_exists ${repo_name} ${release_branch}); then
        # monitor the checks, wait a little until they are registered
        sleep ${delay}
        #set +e
        gh pr checks ${release_branch} \
            --repo ${repo} \
            --watch \
            --interval ${github_refresh_interval}
        #set -e
    fi
}

function create_release() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local tag=$3
    local repo=$(get_gh_repo_path ${repo_name})

    gh release create ${tag} \
        --repo ${repo} \
        --target ${release_branch} \
        --title ${tag} \
        --generate-notes \
        --latest
}

function release_exists() {
    local repo_name=$1
    local tag=$2
    local repo=$(get_gh_repo_path ${repo_name})
    # searching the list of open PRs does not return non-zero value if the search fails
    # gh pr list --state open --search ${release_branch} >/dev/null 2>&1; echo $? # prints 0
    # viewing an non-existent PR on the other hand does fail
    gh release view ${tag} --repo ${repo} >/dev/null 2>&1
}

function merge_release_tag_into_base_branch() {
    show_progress
    local repo_name=$1
    local tag=$2

    if (release_exists ${repo_name} ${tag}); then
        local repo_path=$(get_local_repo_path ${repo_name})
        local base_branch=$(get_default_branch_name ${repo_name})

        # checkout the base branch, fetch everything, we care about the base branch and the latest release tag
        git -C ${repo_path} checkout ${base_branch}
        git -C ${repo_path} status
        git -C ${repo_path} fetch --all
        git -C ${repo_path} status
        git -C ${repo_path} pull
        git -C ${repo_path} status

        # merge the tag into the base branch then push to origin
        # merge conflicts can happen here!
        # for ex when someone on the base branch modified a line this auto release had modified...
        # auto-merge will fail which requires a merge tool as a first step.
        # Merge tools do no guarantee resolving all conflicts automatically. Manual work becomes necessary... Abort or...
        # - If releasing from the head of master, do it or schedule it at an ungodly hour and hope your teammates aren't nocturnal.
        #   Chances of failure will be close to none. This will be the case most of the time.
        # - Try to never release from a (very old) commit
        # - If releasing from an existing tag (usually done for patching old branches without rolling put new  features),
        #   this is where it gets tricky... I really can't think of a way to do this without
        git -C ${repo_path} merge --no-ff ${tag}
        git -C ${repo_path} status
        git -C ${repo_path} push -u origin ${base_branch}
        git -C ${repo_path} status
    fi
}

function update_cpp() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo_path=$(get_local_repo_path ${repo_name})
    # empty commit
    git -C ${repo_path} commit --allow-empty -m "Trigger PR on $release_branch"
    git -C ${repo_path} status
    # push changes to remote
    git -C ${repo_path} push -u origin ${release_branch}
    git -C ${repo_path} status
    return 0
}

function update_py() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # update version of python bindings
    local python_version_file=${work_dir}/${repo_name}/meshkernel/version.py
    python $(get_scripts_path)/bump_mkpy_versions.py \
        --file ${python_version_file} \
        --to_version ${version} \
        --to_backend_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: update versions of python bindings"
}

function update_net() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # update product version
    local nuspec_file=${work_dir}/${repo_name}/nuget/MeshKernelNET.nuspec
    local dir_build_props_file=${work_dir}/${repo_name}/Directory.Build.props
    python $(get_scripts_path)/bump_package_version.py \
        --nuspec_file ${nuspec_file} \
        --dir_build_props_file ${dir_build_props_file} \
        --version_tag "MeshKernelNETVersion" \
        --to_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: update version of product"

    # update versions of dependencies
    local meshkernel_build_number=$(
        python $(get_scripts_path)/get_build_number.py \
            --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    local dir_package_props_file=${work_dir}/${repo_name}/Directory.Packages.props
    python $(get_scripts_path)/bump_dependencies_versions.py \
        --dir_packages_props_file ${dir_package_props_file} \
        --to_versioned_packages "Deltares.MeshKernel:${version}.${meshkernel_build_number}"
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: update versions of dependencies"
}

function rerun_all_workflows() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    local repo=$(get_gh_repo_path ${repo_name})

    workflows_list=$(
        gh workflow list \
            --repo ${repo} \
            --json name \
            --jq '.[].name'
    )

    readarray -t workflows <<<"$workflows_list"

    for workflow in "${workflows[@]}"; do
        echo "Rerunning ${workflow}"
        gh workflow run "${workflow}" \
            --repo ${repo} \
            --ref ${release_branch}
        echo "Waiting for ${workflow} to finish..."
        while [[ ${workflow_status} != "completed" ]]; do
            sleep ${delay}
            workflow_status=$(
                gh run list \
                    --repo ${repo} \
                    --workflow "${workflow}" \
                    --json status \
                    --jq '.[0].status'
            )
        done
        echo "Workflow ${workflow} completed"
    done
}

function print_box() {
    local string="$1"
    local length=${#string}
    local border="+-$(printf "%${length}s" | tr ' ' '-')-+"

    col_echo --green "$border"
    col_echo --green "| $string |"
    col_echo --green "$border"
}

function release() {

    local repo_name=$1
    local update_repo=$2

    print_box "${repo_name} Release v${version}"

    local tag=v${version}
    local release_branch=release/${tag}

    clone ${repo_name}

    check_start_point ${repo_name} ${start_point}

    check_tag ${repo_name} ${tag}

    validate_new_version ${repo_name} ${version}

    create_release_branch ${repo_name} ${release_branch} ${start_point}

    ${update_repo} ${repo_name} ${release_branch}

    create_pull_request ${repo_name} ${release_branch} ${tag}

    monitor_checks ${repo_name} ${release_branch}

    create_release ${repo_name} ${release_branch} ${tag}

    merge_release_tag_into_base_branch ${repo_name} ${tag}
}

# function pin_and_tag_artifacts() {
#     show_progress

#     local release_branch=$1
#     local version=$2
#     local tag=$3
#     local teamcity_access_token=$4

#     python $(get_scripts_path)/pin_artifact.py \
#         --branch_name ${release_branch} \
#         --artifact_name meshkernel-${version}-py3-none-winn_arm64.whl \
#         --build_config_id GridEditor_MeshKernelPyTest_Windows_BuildPythonWheel \
#         --tag ${tag} \
#         --teamcity_access_token ${teamcity_access_token}

#     python $(get_scripts_path)/pin_artifact.py \
#         --branch_name ${release_branch} \
#         --artifact_name meshkernel-${version}-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl \
#         --build_config_id GridEditor_MeshKernelPyTest_Linux_BuildPythonWheel \
#         --tag ${tag} \
#         --teamcity_access_token ${teamcity_access_token}

#     # pin the last MeshKernel build
#     python $(get_scripts_path)/pin_artifact.py \
#         --branch_name ${release_branch} \
#         --artifact_name NuGetContent.zip \
#         --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
#         --tag ${tag} \
#         --teamcity_access_token ${teamcity_access_token}
#     # get the pinned build number
#     local meshkernel_build_number=$(
#         python $(get_scripts_path)/get_build_number.py \
#             --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
#             --version ${version} \
#             --teamcity_access_token ${teamcity_access_token}
#     )
#     # pin the MeshKernel nupkg
#     python $(get_scripts_path)/pin_artifact.py \
#         --branch_name ${release_branch} \
#         --artifact_name Deltares.MeshKernel.${version}.${meshkernel_build_number}.nupkg \
#         --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Package_MeshKernelSigned \
#         --tag ${tag} \
#         --teamcity_access_token ${teamcity_access_token}

#     # pin the last MeshKernelNET build
#     python $(get_scripts_path)/pin_artifact.py \
#         --branch_name ${release_branch} \
#         --artifact_name output.zip \
#         --build_config_id GridEditor_MeshKernelNetTest_Build \
#         --tag ${tag} \
#         --teamcity_access_token ${teamcity_access_token}
#     # get the pinned build number
#     local meshkernelnet_build_number=$(
#         python $(get_scripts_path)/get_build_number.py \
#             --build_config_id GridEditor_MeshKernelNetTest_Build \
#             --version ${version} \
#             --teamcity_access_token ${teamcity_access_token}
#     )
#     # pin the MeshKernelNET nupkg
#     python $(get_scripts_path)/pin_artifact.py \
#         --branch_name ${release_branch} \
#         --artifact_name MeshKernelNET.${version}.${meshkernelnet_build_number}.nupkg \
#         --build_config_id GridEditor_MeshKernelNetTest_NuGet_MeshKernelNETSigned \
#         --tag ${tag} \
#         --teamcity_access_token ${teamcity_access_token}
# }

function pin_and_tag_artifacts_cpp() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    # pin the last MeshKernel build
    python $(get_scripts_path)/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name NuGetContent.zip \
        --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
    # get the pinned build number
    local meshkernel_build_number=$(
        python $(get_scripts_path)/get_build_number.py \
            --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    # pin the MeshKernel nupkg
    python $(get_scripts_path)/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name Deltares.MeshKernel.${version}.${meshkernel_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Package_MeshKernelSigned \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
}

function pin_and_tag_artifacts_py() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    python $(get_scripts_path)/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name meshkernel-${version}-py3-none-win_amd64.whl \
        --build_config_id GridEditor_MeshKernelPyTest_Windows_BuildPythonWheel \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}

    python $(get_scripts_path)/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name meshkernel-${version}-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl \
        --build_config_id GridEditor_MeshKernelPyTest_Linux_BuildPythonWheel \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
}

function pin_and_tag_artifacts_net() {
    show_progress

    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    # pin the last MeshKernelNET build
    python $(get_scripts_path)/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name output.zip \
        --build_config_id GridEditor_MeshKernelNetTest_Build \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
    # get the pinned build number
    local meshkernelnet_build_number=$(
        python $(get_scripts_path)/get_build_number.py \
            --build_config_id GridEditor_MeshKernelNetTest_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    # pin the MeshKernelNET nupkg
    python $(get_scripts_path)/pin_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name MeshKernelNET.${version}.${meshkernelnet_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernelNetTest_NuGet_MeshKernelNETSigned \
        --tag ${tag} \
        --teamcity_access_token ${teamcity_access_token}
}

function download_artifacts() {
    show_progress
    local release_branch=$1
    local version=$2
    local tag=$3
    local teamcity_access_token=$4

    mkdir ${work_dir}/artifacts

    mkdir ${work_dir}/artifacts/python_wheels
    python $(get_scripts_path)/download_python_wheels.py \
        --version ${version} \
        --destination ${work_dir}/artifacts/python_wheels \
        --teamcity_access_token ${teamcity_access_token}

    mkdir ${work_dir}/artifacts/nupkg

    local meshkernel_build_number=$(
        python $(get_scripts_path)/get_build_number.py \
            --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    python $(get_scripts_path)/download_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name Deltares.MeshKernel.${version}.${meshkernel_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Package_MeshKernelSigned \
        --tag ${tag} \
        --destination ${work_dir}/artifacts/nupkg \
        --teamcity_access_token ${teamcity_access_token}

    local meshkernelnet_build_number=$(
        python $(get_scripts_path)/get_build_number.py \
            --build_config_id GridEditor_MeshKernelNetTest_Build \
            --version ${version} \
            --teamcity_access_token ${teamcity_access_token}
    )
    python $(get_scripts_path)/download_artifact.py \
        --branch_name ${release_branch} \
        --artifact_name MeshKernelNET.${version}.${meshkernelnet_build_number}.nupkg \
        --build_config_id GridEditor_MeshKernelNetTest_NuGet_MeshKernelNETSigned \
        --tag ${tag} \
        --destination ${work_dir}/artifacts/nupkg \
        --teamcity_access_token ${teamcity_access_token}
}

function rebuild_cpp {
    local release_branch=$1
    local teamcity_access_token=$2
    python $(get_scripts_path)/trigger_build.py \
        --branch_name ${release_branch} \
        --build_config_id GridEditor_MeshKernelBackEndTest_Windows_Build \
        --refresh_interval 10 \
        --teamcity_access_token ${teamcity_access_token}
}

function create_conda_env() {
    conda env create -f $(get_scripts_path)/release_conda_env.yml
    activate release_conda_env
}

function remove_conda_env() {
    conda deactivate
    conda remove -y -n release_conda_env --all
}

function main() {

    local start_time=$(date +%s)

    parse_arguments "$@"
    check_version_string ${version}
    check_time_value "github_refresh_interval" ${github_refresh_interval}
    check_time_value "delay" ${delay}

    print_box "Release v${version}"

    log_in

    create_work_dir

    local tag=v${version}
    local release_branch=release/${tag}

    create_conda_env

    release "MeshKernelTest" update_cpp
    rebuild_cpp ${release_branch} ${teamcity_access_token}
    pin_and_tag_artifacts_cpp ${release_branch} ${version} ${tag} ${teamcity_access_token}

    release "MeshKernelPyTest" update_py
    pin_and_tag_artifacts_py ${release_branch} ${version} ${tag} ${teamcity_access_token}

    release "MeshKernelNETTest" update_net
    pin_and_tag_artifacts_net ${release_branch} ${version} ${tag} ${teamcity_access_token}

    #pin_and_tag_artifacts ${release_branch} ${version} ${tag} ${teamcity_access_token}

    download_artifacts ${release_branch} ${version} ${tag} ${teamcity_access_token}

    remove_conda_env

    remove_work_dir

    log_out

    local end_time=$(date +%s)
    local elapsed_time=$((end_time - start_time))
    print_box "Release v${version} took $(date -u -d "@$elapsed_time" +%H:%M:%S)"
}

main "$@"
