#!/bin/bash

declare -gi github_refresh_interval=30 # seconds
declare -gi delay=${github_refresh_interval}
declare -g release_grid_editor_plugin=false
declare -g dhydro_suite_version=""
declare -g upload_to_pypi=false
declare -g pypi_access_token=""
declare -g teamcity_access_token=""
declare -g clean=false

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
            shift 2
            ;;
        --version)
            declare -g version="$2"
            shift 2
            ;;
        --release_grid_editor_plugin)
            release_grid_editor_plugin=true
            shift
            ;;
        --dhydro_suite_version)
            dhydro_suite_version="$2"
            shift 2
            ;;
        --start_point)
            declare -g start_point="$2"
            shift 2
            ;;
        --github_access_token)
            declare -g github_access_token="$2"
            shift 2
            ;;
        --github_refresh_interval)
            github_refresh_interval="$2"
            shift 2
            ;;
        --upload_to_pypi)
            upload_to_pypi=true
            shift
            ;;
        --pypi_access_token)
            pypi_access_token="$2"
            shift 2
            ;;
        --teamcity_access_token)
            teamcity_access_token="$2"
            shift 2
            ;;
        --delay)
            delay="$2"
            shift 2
            ;;
        --clean)
            clean=true
            shift
            ;;
        -* | --*)
            echo "Unknown parameter $1"
            do_exit=true
            shift
            ;;
        *)
            positional_args+=("$1") # save positional arg
            shift                   # past argument
            ;;
        esac
    done

    # required parameters
    if [[ -z ${work_dir} ]]; then
        echo "Missing parameter --work_dir."
        do_exit=true
    elif [[ -z ${version} ]]; then
        echo "Missing parameter --version."
        do_exit=true
    elif [[ -z ${start_point} ]]; then
        echo "Missing parameter --start_point."
        do_exit=true
    elif [[ -z ${github_access_token} ]]; then
        echo "Missing parameter --github_access_token."
        do_exit=true
    elif ! test -f "${teamcity_access_token}"; then
        echo "Missing parameter --teamcity_access_token."
        do_exit=true
    fi

    # dependent parameters
    if ${upload_to_pypi}; then
        if ! test -f "${pypi_access_token}"; then
            echo "Missing parameter --pypi_access_token: required when --upload_to_pypi is provided."
            do_exit=true
        fi
    fi

    if ${release_grid_editor_plugin}; then
        if [[ -z ${dhydro_suite_version} ]]; then
            echo "Missing parameter --dhydro_suite_version"
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

function check_version_string() {
    local version=$1
    local pattern="^[0-9]+\.[0-9]+\.[0-9]+$"
    if ! [[ $version =~ $pattern ]]; then
        echo "The string \"$version\" does not correspond to a semantic version of the form <major>.<minor>.<patch>."
        exit 1
    fi
}

function check_time_value() {
    local name=$1
    local value=$2
    if [[ $2 -le 0 ]]; then
        echo "$1 must be a positive integer."
        exit 1
    fi
}

function check_arguments() {
    check_version_string ${version}
    check_time_value "github_refresh_interval" ${github_refresh_interval}
    check_time_value "delay" ${delay}
}
