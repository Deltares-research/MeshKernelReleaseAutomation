#!/bin/bash

function upload_python_wheels_to_github() {
    show_progress
    local tag=$1
    local meshkernelpy_repo=$(get_gh_repo_path ${repo_name_MeshKernelPy})
    for wheel in "${work_dir}/artifacts/python_wheels"/*".whl"; do
        echo "Uploading MeshKernel ${wheel}..."
        gh release upload ${tag} ${wheel} \
            --repo ${meshkernelpy_repo} \
            --clobber
    done
}

function upload_nuget_packages_to_github() {
    show_progress
    local tag=$1

    echo "Uploading MeshKernel nupkg..."
    local meshkernel_repo=$(get_gh_repo_path ${repo_name_MeshKernel})
    gh release upload \
        ${tag} ${work_dir}/artifacts/nuget_packages/Deltares.MeshKernel.*.nupkg \
        --repo ${meshkernel_repo} \
        --clobber

    echo "Uploading MeshKernelNET nupkg..."
    local meshkernelnet_repo=$(get_gh_repo_path ${repo_name_MeshKernelNET})
    gh release upload \
        ${tag} ${work_dir}/artifacts/nuget_packages/MeshKernelNET.*.nupkg \
        --repo ${meshkernelnet_repo} \
        --clobber

    echo "Uploading GridEditor nupkg..."
    if ${release_grid_editor_plugin}; then
        local grideditorplugin_repo=$(get_gh_repo_path ${repo_name_GridEditorPlugin})
        gh release upload \
            ${tag} ${work_dir}/artifacts/nuget_packages/DeltaShell.Plugins.GridEditor.*.nupkg \
            --repo ${grideditorplugin_repo} \
            --clobber
    fi
}

function upload_msi_to_github() {
    show_progress
    local tag=$1
    if ${release_grid_editor_plugin}; then
        local grideditorplugin_repo=$(get_gh_repo_path ${repo_name_GridEditorPlugin})
        gh release upload \
            ${tag} ${work_dir}/artifacts/msi/D-GridEditor*.msi \
            --repo ${grideditorplugin_repo} \
            --clobber
    fi
}

function upload_python_wheels_to_pypi() {
    show_progress
    local access_token_file=$1
    local access_token=$(<${access_token_file})
    python -m twine upload \
        --verbose \
        --username __token__ \
        --password ${access_token} \
        ${work_dir}/artifacts/python_wheels/*.whl
}
