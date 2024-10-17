#!/bin/bash

function create_work_dir() {
    show_progress
    if [ -d "${work_dir}" ]; then
        rm -rf "${work_dir}"
    fi
    mkdir -p ${work_dir}
}

function remove_work_dir() {
    show_progress
    if ${clean}; then
        rm -fr "${work_dir}"
    fi
}

function get_local_repo_path() {
    local repo_name=$1
    echo ${work_dir}/${repo_name}
}
