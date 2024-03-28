#!/bin/bash

set -e

repo_host=github.com
repo_owner=Deltares-research

gh_refresh_interval=30 # seconds
wait=${gh_refresh_interval}
clean=false

function show_progress() {
    echo ">> Executing: ${FUNCNAME[1]}"
}

function get_scripts_dir() {
    local script_path=$0
    echo $(dirname $(realpath "$0"))
}

function catch() {
    local exit_code=$1
    if [ ${exit_code} != "0" ]; then
        echo "Error occurred"
        echo "  Line     : ${BASH_LINENO[1]}"
        echo "  Function : ${FUNCNAME[1]}"
        echo "  Command  : ${BASH_COMMAND}"
        echo "  Exit code: ${exit_code}"
    fi
}

trap 'catch $?' EXIT

function usage {
    echo "Usage: $0 --version string --base_branch string --gh_token string --gh_refresh_interval integer --wait integer"
    echo "Creates a new release"
    echo ""
    echo "  --work_dir             Required  string   Path to work directory"
    echo "  --version              Required  string   Version of new release"
    echo "  --start_point          Required  string   ID of commit, branch or tag to check out"
    echo "                                            If provided, it should belong to the specified base branch. "
    echo "                                            Otherwise the HEAD of  the base branch is checked out."
    echo "  --gh_token             Required  string   Path to github token"
    echo "  --gh_refresh_interval  Optional  integer  Refresh interval in seconds "
    echo "                                            Used as a refresh interval while watching github PR checks, default = 30s"
    echo "  --wait                 Optional  integer  Wait duration in seconds"
    echo "                                            The script sleeps for this duration before watching github PR checks, default = 30s"
    echo "  --clean                Optional           If supplied, the working directory is removed. Otherwise, it is kept."
    echo ""
}

# Define the parse_named_arguments function
function parse_arguments() {
    show_progress
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
        --gh_token)
            declare -g gh_token="$2"
            shift # past argument
            shift # past value
            ;;
        --gh_refresh_interval)
            declare -gi gh_refresh_interval="$2"
            shift # past argument
            shift # past value
            ;;
        --wait)
            declare -gi wait="$2"
            shift # past argument
            shift # past value
            ;;
        --clean)
            declare -g clean=true
            shift # past argument
            ;;
        -* | --*)
            echo "Unknown option $1"
            usage
            exit 1
            ;;
        *)
            positional_args+=("$1") # save positional arg
            shift                   # past argument
            ;;
        esac
    done

    if ((${#positional_args[@]})); then
        echo "Found positional arguments (${positional_args[@]}). Such arguments are not allowed. Only named arguments are valid."
        usage
        exit 1
    fi
}

function log_in() {
    show_progress
    gh auth login --with-token <${gh_token}
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
    local repo_name=$1
    local repo_path=$(get_local_repo_path ${repo_name})
    # determine the nature of the starting point
    local start_point=$2
    if (git -C ${repo_path} show-ref --tags --verify --quiet -- refs/tags/${start_point} >/dev/null 2>&1); then
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
    # switch to release branch
    git -C ${repo_path} checkout -B ${release_branch} ${start_point}
    git -C ${repo_path} status
    # and immediately push it to remote
    git -C ${repo_path} push -f origin ${release_branch}
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
    local repo_name=$1
    local release_branch=$2
    local start_point=$3
    local repo_path=$(get_local_repo_path ${repo_name})
    # is this really te best way?
    if [ -n "$(git -C ${repo_path} log --oneline ${release_branch}..${start_point})" ]; then
        return 0
    fi
    return 1
}

function pull_request_exists() {
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
    #if (branch_has_new_commits ${repo_name} ${release_branch} ${start_point}) &&
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
    #fi
}

function monitor_checks() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo=$(get_gh_repo_path ${repo_name})
    #if (pull_request_exists ${repo_name} ${release_branch}); then
    # monitor the checks, wait a little until they are registered
    sleep ${wait}
    set +e
    gh pr checks ${release_branch} \
        --repo ${repo} \
        --watch \
        --interval ${gh_refresh_interval}
    set -e
    #fi
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
        git -C ${repo_path} fetch --all
        git -C ${repo_path} pull

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
        git -C ${repo_path} push -u origin ${base_branch}
    fi
}

function update_cpp() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo_path=$(get_local_repo_path ${repo_name})
    # empty commit
    git -C ${repo_path} commit --allow-empty -m "Trigger PR on $release_branch"
    # push changes to remote
    git -C ${repo_path} push -u origin ${release_branch}
    return 0
}

function update_py() {
    show_progress
    local repo_name=$1
    local release_branch=$2

    # update version of python bindings
    local python_version_file=${work_dir}/${repo_name}/DummyProductPY/version.py
    python ${scripts_dir}/bump_mkpy_versions.py \
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

    # download artifact from backend and upload it to repository
    # this must be removed
    local repo=$(get_gh_repo_path "DummyProductCPP")
    local last_run_id=$(
        gh run list \
            --repo=${repo} \
            --workflow="Build and deploy" \
            --branch=${release_branch} \
            --limit=1 \
            --json databaseId \
            --jq '.[].databaseId'
    )
    gh run download $last_run_id \
        --repo=${repo} \
        --name="packages-windows-2022-Release" \
        --dir ${work_dir}/${repo_name}/dependencies
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: upload Deltares.DummyProductCPP nupkg"

    # update product version
    local nuspec_file=${work_dir}/${repo_name}/nuget/DummyProductNET.nuspec
    local dir_build_props_file=${work_dir}/${repo_name}/Directory.Build.props
    python ${scripts_dir}/bump_package_version.py \
        --nuspec_file ${nuspec_file} \
        --dir_build_props_file ${dir_build_props_file} \
        --version_tag "DummyProductNETVersion" \
        --to_version ${version}
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: update version of product"

    # update versions of dependencies
    local dir_package_props_file=${work_dir}/${repo_name}/Directory.Packages.props
    python ${scripts_dir}/bump_dependencies_versions.py \
        --dir_packages_props_file ${dir_package_props_file} \
        --to_versioned_packages "Deltares.DummyProductCPP:${version}"
    commit_and_push_changes ${repo_name} ${release_branch} \
        "Release v${version} auto-update: update versions of dependencies"
}

function rerun_all_workflows() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo=$(get_gh_repo_path ${repo_name})

    workflows_list=$(gh workflow list --repo ${repo} --json name --jq '.[].name')
    readarray -t workflows <<<"$workflows_list"
    for workflow in "${workflows[@]}"; do
        echo "Rerunning $workflow"
        gh workflow run "$workflow" --repo ${repo} --ref ${release_branch}
    done
}

print_box() {
    local string="$1"
    local length=${#string}
    local border="+-$(printf "%${length}s" | tr ' ' '-')-+"

    echo "$border"
    echo "| $string |"
    echo "$border"
}

function release() {

    local repo_name=$1
    local update_repo=$2
    local do_rerun_all_workflows=$3

    print_box ${repo_name}

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

    # create tagged release from the release branch, set title same as tag, autogenerate the release notes and set it to latest
    create_release ${repo_name} ${release_branch} ${tag}

    if [[ ${do_rerun_all_workflows} -eq 1 ]]; then
        rerun_all_workflows ${repo_name} ${release_branch}
        monitor_checks ${repo_name} ${release_branch}
    fi

    # merge the newly created release tag into the base branch
    merge_release_tag_into_base_branch ${repo_name} ${tag}
}

main() {

    local scripts_dir=$(get_scripts_dir)

    parse_arguments "$@"
    check_version_string ${version}
    check_time_value "gh_refresh_interval" ${gh_refresh_interval}
    check_time_value "wait" ${wait}

    log_in
    create_work_dir

    release "DummyProductCPP" update_cpp 1

    release "DummyProductPY" update_py 0

    release "DummyProductNET" update_net 0

    remove_work_dir
    log_out
}

main "$@"
