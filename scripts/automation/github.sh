#!/bin/bash

function log_in() {
    show_progress
    gh auth login --with-token <${github_access_token}
}

function log_out() {
    show_progress
    gh auth logout
}

function get_gh_repo_path() {
    local repo_name=$1
    echo ${repo_host}/${repo_owner}/${repo_name}
}

function clone() {
    show_progress
    local repo_url=git@${repo_host}:${repo_owner}/$1.git
    local destination=${work_dir}/$1
    git clone ${repo_url} ${destination}
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
        exit 1
    fi
}

function check_tag() {
    local repo_name=$1
    local tag=$2
    local repo_path=$(get_local_repo_path ${repo_name})
    if (git -C ${repo_path} ls-remote --exit-code --tags origin ${tag} >/dev/null 2>&1); then
        echo "Tag ${tag} exists. Verify that the new version is correct."
        exit 1
    fi
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
            echo "Upgrading from ${latest_version_string} to ${new_version_string}"
            return 0
        elif ((${new_version_segment} < ${latest_version_segment})); then
            echo "Cannot upgrade to specified version: new version (${new_version_string}) < latest version (${latest_version_string})"
            exit 1
        fi
    done

    # Versions are equal
    echo "Cannot upgrade to specified version: new version = latest version (${latest_version_string})"
    exit 1
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

    if ! (on_branch ${repo_name} ${release_branch}); then exit 1; fi
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

function branch_has_new_commits() {
    show_progress
    local repo_name=$1
    local start_point=$2
    local release_branch=$3
    local repo_path=$(get_local_repo_path ${repo_name})
    # is this really the best way?
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

function monitor_pull_request_checks() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local repo=$(get_gh_repo_path ${repo_name})
    if (pull_request_exists ${repo_name} ${release_branch}); then
        # monitor the checks, wait a little until they are registered
        sleep ${delay}
        gh pr checks ${release_branch} \
            --repo ${repo} \
            --watch \
            --interval ${github_refresh_interval}
    fi
}

function release_exists_and_is_latest() {
    local repo_name=$1
    local tag=$2
    local repo=$(get_gh_repo_path ${repo_name})
    local result=$(gh release list \
        --repo ${repo} \
        --json tagName,isLatest \
        --jq ".[] \
        | select(.tagName == \"${tag}\" and .isLatest == true)")
    if [[ -n "${result}" ]]; then
        return 0
    else
        return 1
    fi
}

function create_release() {
    show_progress
    local repo_name=$1
    local release_branch=$2
    local tag=$3
    local repo=$(get_gh_repo_path ${repo_name})

    if (gh release create ${tag} \
        --repo ${repo} \
        --target ${release_branch} \
        --title ${tag} \
        --generate-notes \
        --latest); then
        return 0
    else
        return 1
    fi
}

function merge_release_tag_into_base_branch() {
    show_progress
    local repo_name=$1
    local tag=$2

    if (release_exists_and_is_latest ${repo_name} ${tag}); then
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
        # - If releasing from the head of master, do it or schedule it at late time and hope your teammates aren't nocturnal.
        #   Chances of failure will be close to none. This will be the case most of the time.
        # - Try to never release from a (very old) commit
        # - If releasing from an existing tag (usually done for patching old branches without rolling out new features),
        #   this is where it gets tricky... I really can't think of a way to do this
        git -C ${repo_path} merge --no-ff ${tag}
        git -C ${repo_path} status
        git -C ${repo_path} push -u origin ${base_branch}
        git -C ${repo_path} status
    fi
}

function monitor_checks_on_base_branch() {
    show_progress
    local repo_name=$1
    local base_branch=$(get_default_branch_name ${repo_name})
    echo "${repo_name}" "${base_branch}"
    monitor_checks_on_branch "${repo_name}" "${base_branch}"
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
