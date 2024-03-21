#!/bin/bash

# set -x

set -e

gh_refresh_interval=30 # seconds
wait=${gh_refresh_interval}
ERROR_MESSAGE=''

function usage {
    echo "Usage: $0 --version string --base_branch string --gh_token string "
    echo "Creates a new release"
    echo ""
    echo "  --version              Required  string   Version of new release"
    echo "  --base_branch          Required  string   Base branch"
    echo "  --start_point          Required  string   ID of commit, branch or tag to check out"
    echo "                                            If provided, it should belong to the specified base branch. "
    echo "                                            Otherwise the HEAD of  the base branch is checked out."
    echo "  --gh_token             Required  string   Path to github token"
    echo "  --gh_refresh_interval  Optional  integer  Refresh interval in seconds "
    echo "                                            Used as a refresh interval while watching github PR checks, default = 30s"
    echo "  --wait                 Optional  integer  Wait duration in seconds"
    echo "                                            The script sleeps for this duration before watching github PR checks, default = 30s"
    echo ""
}

function catch() {
    local exit_code=$1
    if [ ${exit_code} != "0" ]; then
        echo "Error occurred"
        echo "  Line     : ${BASH_LINENO[1]}"
        echo "  Function : ${FUNCNAME[1]}"
        echo "  Command  : ${BASH_COMMAND}"
        echo "  Exit code: ${exit_code}"
        if ! [ -z "$ERROR_MESSAGE" ]; then
            echo "  Message  : ${ERROR_MESSAGE}"
        fi
    fi
}

trap 'catch $?' EXIT

function error() {
    # store last exit code before invoking any other command
    local exit_code="$?"
    # print error message
    echo Error: "$1"
    exit $exit_code
}

function die {
    printf "Script failed: %s\n" "$1"
    usage
    exit 1
}

#function parse_args() {
while [ $# -gt 0 ]; do
    if [[ $1 == "--help" ]]; then
        usage
        exit 0
    elif [[ $1 == "--"* ]]; then
        v="${1/--/}"
        declare -g "$v"="$2"
        shift
    fi
    shift
done
#}

#function check_args() {
if [[ -z ${version} ]]; then
    die "Missing parameter --version"
elif [[ -z ${base_branch} ]]; then
    die "Missing parameter --base_branch"
elif [[ -z ${start_point} ]]; then
    die "Missing parameter --start_point"
elif [[ -z ${gh_token} ]]; then
    die "Missing parameter --gh_token"
fi
#}

function check_version() {
    local version=$1
    local pattern="^[0-9]+\.[0-9]+\.[0-9]+$"
    if [[ $version =~ $pattern ]]; then
        echo "Release version will be set to $version."
    else
        error "The string \"$version\" does not correspond to a semantic <major>.<minor>.<patch>."
    fi
}

#parse_args
echo version is ${version}
#check_args
check_version ${version}

tag=v${version}
release_branch=release/${tag}

scripts_dir=.

repo_host=github.com
repo_owner=Deltares-research
repo_name=MeshKernelReleaseAutomation
work_dir=release

python_version_file=${work_dir}/${repo_name}/python/version.py
nuspec_file=${work_dir}/${repo_name}/nuget/MeshKernelReleaseAutomation.nuspec
dir_build_props_file=${work_dir}/${repo_name}/Directory.Build.props
dir_package_props_file=${work_dir}/${repo_name}/Directory.Packages.props

function log_in() {
    gh auth login --with-token <${gh_token}
}

function log_out() {
    gh auth logout
}

function create_work_dir() {
    mkdir -p ${work_dir}
    rm -fr ${work_dir}/*
}

function clean() {
    rm -fr ${work_dir}
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
    local repo_url=git@${repo_host}:${repo_owner}/$1.git
    local destination=${work_dir}/$1
    git clone ${repo_url} ${destination}
}

function check_start_point() {
    local repo_name=$1
    local repo_path=$(get_local_repo_path ${repo_name})
    # determine the nature of the starting point
    local start_point=$2
    if git -C ${repo_path} show-ref --tags --verify --quiet -- refs/tags/${start_point} >/dev/null 2>&1; then
        echo Starting point is ${start_point}, which is a tag.
    elif git -C ${repo_path} show-ref --verify --quiet -- refs/heads/${start_point} >/dev/null 2>&1; then
        echo Starting point is ${start_point}, which is a branch.
    elif git -C ${repo_path} rev-parse --verify ${start_point}^{commit} >/dev/null 2>&1; then
        echo Starting point is ${start_point}, which is a commit.
    else
        error ${start_point} is neither a commit ID, a tag, nor a branch.
    fi
}

function create_release_branch() {
    local repo_name=$1
    local release_branch=$2
    local start_point=$3
    local repo_path=$(get_local_repo_path ${repo_name})
    # pull remote
    git -C ${repo_path} pull origin ${start_point}
    # switch to release branch
    git -C ${repo_path} checkout -B ${release_branch} ${start_point}
    # and immediately push it to remote
    git -C ${repo_path} push -f origin ${release_branch}
}

function get_default_branch_name() {
    local repo_name=$1
    local repo_path=$(get_local_repo_path ${repo_name})
    echo $(git -C ${repo_path} symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
}

function commit_and_push_changes() {
    local repo_name=$1
    local release_branch=$2
    local message=$3
    local repo_path=$(get_local_repo_path ${repo_name})
    git -C ${repo_path} add --all # brute force, maybe too much
    git -C ${repo_path} commit -m "$message"
    git -C ${repo_path} push -u origin ${release_branch}
}

function create_pull_request() {
    local repo_name=$1
    local release_branch=$2
    local tag=$3
    local repo=$(get_gh_repo_path ${repo_name})
    # different repos have different default branch names, such as master or main
    local base_branch=$(get_default_branch_name ${repo_name})

    gh pr create \
        --repo ${repo} \
        --base ${base_branch} \
        --head ${release_branch} \
        --title "Release ${tag}" \
        --body "Release ${tag}"
    # for some reason --fill does  not work
}

function monitor_checks() {
    local repo_name=$1
    local repo=$(get_gh_repo_path ${repo_name})
    sleep ${wait}
    gh pr checks ${release_branch} \
        --repo ${repo} \
        --watch \
        --interval ${gh_refresh_interval} ||
        error "One or more checks failed"
}

function create_release() {
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

function merge_release_tag_into_base_branch() {
    local repo_name=$1
    local tag=$2

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
    git -C ${repo_path} merge --no-ff ${tag} || error "Merge tag failed highly likely due to merge conflicts"
    git -C ${repo_path} push -u origin ${base_branch}
}

function main() {
    log_in

    create_work_dir

    clone ${repo_name}

    check_start_point ${repo_name} ${start_point}

    create_release_branch ${repo_name} ${release_branch} ${start_point}

    # update version of python bindings
    python ${scripts_dir}/bump_mkpy_versions.py \
        --file ${python_version_file} \
        --to_version ${version} \
        --to_backend_version ${version}

    commit_and_push_changes ${repo_name} ${release_branch} "Auto-update versions of python bindings"

    # release has now diverged from the base branch, create a PR
    create_pull_request ${repo_name} ${release_branch} ${tag}

    monitor_checks ${repo_name}

    # update product version
    python ${scripts_dir}/bump_package_version.py \
        --nuspec_file ${nuspec_file} \
        --dir_build_props_file ${dir_build_props_file} \
        --version_tag "MeshKernelReleaseAutomationVersion" \
        --to_version ${version}

    commit_and_push_changes ${repo_name} ${release_branch} "Auto-update version of product"

    monitor_checks ${repo_name}

    # update versions of dependencies
    python ${scripts_dir}/bump_dependencies_versions.py \
        --dir_packages_props_file ${dir_package_props_file} \
        --to_versioned_packages "Deltares.MeshKernel:${version}  Invalid:2666.09.13   DHYDRO.SharedConfigurations:6.6.6.666   NUnit:3.12.6"

    commit_and_push_changes ${repo_name} ${release_branch} "Auto-update versions of dependencies"

    monitor_checks ${repo_name}

    # create tagged release from the release branch, set title same as tag, autogenerate the release notes and set it to latest
    create_release ${repo_name} ${release_branch} ${tag}

    # merge the newly created release tag into the base branch
    merge_release_tag_into_base_branch ${repo_name} ${tag}

    # log out
    log_out
}

main

# set +x
