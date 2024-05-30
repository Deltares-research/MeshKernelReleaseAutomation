#!/bin/bash

# Get the latest commit SHA on a given branch in a given repository
function get_latest_commit_sha_path() {
    local repo_name=$1
    local branch=$2
    local latest_commit_sha=$(gh api repos/${repo_owner}/${repo_name}/commits/${branch} -q '.sha')
    echo "repos/${repo_owner}/${repo_name}/commits/${latest_commit_sha}"
}

# Lists GitHub Actions workflows using check-runs
function check_github_check_runs_list() {
    local commit_sha_path=$1
    echo "Checking GitHub actions"
    local check_runs=$(gh api ${commit_sha_path}/check-runs)
    echo "${check_runs}" | jq -c '.check_runs[]' | while read -r run; do
        local id=$(echo "$run" | jq -r '.id')
        local name=$(echo "$run" | jq -r '.name')
        local status=$(echo "$run" | jq -r '.status')
        local conclusion=$(echo "$run" | jq -r '.conclusion')
        echo "Check Run ID: ${id}, Name: ${name}, Status: ${status}, Conclusion: ${conclusion}"
    done
}

# Checks the completion of GitHub Actions workflows using check-runs
function check_github_check_runs_completion() {
    local commit_sha_path=$1
    local check_runs=$(gh api ${commit_sha_path}/check-runs)
    local incomplete_runs=$(echo "${check_runs}" |
        jq -r '[.check_runs[] | select(.status != "completed")] | length')
    echo "${incomplete_runs}"
}

# Checks the success of GitHub Actions workflows using check-runs
function check_github_check_runs_success() {
    local commit_sha_path=$1
    local check_runs=$(gh api ${commit_sha_path}/check-runs)
    local unsuccessful_runs=$(echo "${check_runs}" |
        jq -r '[.check_runs[] | select(.conclusion != "success")] | length')
    echo "${unsuccessful_runs}"
}

# Lists the completion of the statuses API endpoint
function check_github_statuses_list() {
    local commit_sha_path=$1
    echo "Checking GitHub statuses"
    local statuses=$(gh api ${commit_sha_path}/status)
    echo "$statuses" | jq -c '.statuses[]' | while read -r status; do
        local context=$(echo "$status" | jq -r '.context')
        local state=$(echo "$status" | jq -r '.state')
        local description=$(echo "$status" | jq -r '.description')
        echo "Context: ${context}, State: ${state}, Description: ${description}"
    done
}

function check_github_statuses_completion() {
    local commit_sha_path=$1
    local statuses=$(gh api ${commit_sha_path}/status)
    # exclude pending status
    local incomplete_statuses=$(echo "${statuses}" |
        jq -r '[.statuses[] | select(.state != "success" and .state != "error" and .state != "failure")] | length')
    echo "${incomplete_statuses}"
}

# Checks the success of the statuses API endpoint
function check_github_statuses_success() {
    local commit_sha_path=$1
    local statuses=$(gh api ${commit_sha_path}/status)
    local unsuccessful_runs=$(echo "${statuses}" |
        jq -r '[.statuses[] | select(.state != "success")] | length')
    echo "${unsuccessful_runs}"
}

# Monitors all jobs on a given branch in a given repository
function monitor_checks_on_branch() {
    local repo_name=$1
    local branch=$2

    # wait to allow queuing of jobs
    sleep ${delay}

    local latest_commit_sha_path=$(get_latest_commit_sha_path ${repo_name} ${branch})
    echo "Last commit: ${latest_commit_sha_path}"
    while true; do
        local check_runs_log=$(check_github_check_runs_list "${latest_commit_sha_path}")
        local check_runs_line_count=$(echo "${check_runs_log}" | wc -l)

        local statuses_log=$(check_github_statuses_list "${latest_commit_sha_path}")
        local statuses_line_count=$(echo "${statuses_log}" | wc -l)

        echo "$check_runs_log"
        echo "$statuses_log"

        local incomplete_check_runs=$(check_github_check_runs_completion "${latest_commit_sha_path}")
        local incomplete_statuses=$(check_github_statuses_completion "${latest_commit_sha_path}")
        #echo ">>>>> $incomplete_check_runs"
        #echo ">>>>> $incomplete_statuses"
        if [[ "${incomplete_check_runs}" -eq 0 && "${incomplete_statuses}" -eq 0 ]]; then
            echo "All jobs completed"
            break
        fi

        sleep ${github_refresh_interval}
        local lines_to_clear=$((${check_runs_line_count} + ${statuses_line_count}))
        tput cuu ${lines_to_clear}
        # for ((i = 0; i < line_count; i++)); do
        #     printf "\r\e[K"
        # done
    done

    local unsuccessful_check_runs=$(check_github_check_runs_success "${latest_commit_sha_path}")
    local unsuccessful_statuses=$(check_github_statuses_success "${latest_commit_sha_path}")
    if [[ "${unsuccessful_check_runs}" -eq 0 && "${unsuccessful_statuses}" -eq 0 ]]; then
        echo "All jobs succeeded"
    else
        echo "Some jobs were not successful"
        exit 1
    fi
}
