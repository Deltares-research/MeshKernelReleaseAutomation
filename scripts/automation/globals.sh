#!/bin/bash

declare -g repo_host="github.com"

declare -g repo_owner="Deltares"
declare -g forked_repo_suffix=""

#declare -g  repo_owner="Deltares-research"
#declare -g  forked_repo_suffix="Test"

declare -g repo_name_MeshKernel="MeshKernel"${forked_repo_suffix}
declare -g repo_name_MeshKernelPy="MeshKernelPy"${forked_repo_suffix}
declare -g repo_name_MeshKernelNET="MeshKernelNET"${forked_repo_suffix}
declare -g repo_name_GridEditorPlugin="Grid_Editor_plugin"${forked_repo_suffix}

declare -g conda_env_name="meshkernel_release"
