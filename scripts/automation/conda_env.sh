#!/bin/bash

function create_conda_env() {
    show_progress
    local conda_env_file=$1
    if ! conda env list | grep -q "\<${conda_env_name}\>"; then
        conda env create -f ${conda_env_file}
    fi
    source activate ${conda_env_name}
}

function remove_conda_env() {
    show_progress
    if conda env list | grep -q "\<${conda_env_name}\>"; then
        conda deactivate
        conda remove -y -n ${conda_env_name} --all
    fi
}
