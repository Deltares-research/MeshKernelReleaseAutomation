#!/bin/bash

set -x

version=$1
github_token_path=$2

base_branch=main
tag=v${version}
release_branch=release/${tag}

scripts_dir=.
root_dir=../..
python_version_file=${root_dir}/python/version.py
nuspec_file=${root_dir}/nuget/MeshKernelReleaseAutomation.nuspec
dir_build_props_file=${root_dir}/Directory.Build.props
dir_package_rops_file=${root_dir}/Directory.Packages.props


# login
gh auth login --with-token < ${github_token_path}

# fetch master and create the release branch
git fetch origin ${base_branch}
git checkout -b ${release_branch} ${base_branch}

# update version of python bindings
python ${scripts_dir}/bump_mkpy_versions.py \
--file ${python_version_file} \
--to_version 6.6.6 \
--to_backend_version 6.6.6
git add ${python_version_file}
git commit -m 'Update python bindings version'
git push -u origin ${release_branch}

# update product version
python ${scripts_dir}/bump_package_version.py \
--nuspec_file ${nuspec_file} \
--dir_build_props_file ${dir_build_props_file} \
--version_tag "MeshKernelReleaseAutomationVersion" \
--to_version 6.6.6
git add ${nuspec_file} ${dir_build_props_file}
git commit -m 'update product version'
git push -u origin ${release_branch}

# update versions of dependencies
python ${scripts_dir}/bump_dependencies_versions.py \
--dir_packages_props_file ${dir_package_rops_file} \
--to_versioned_packages \
  "Deltares.MeshKernel:6.6.6.666-dev  \
  Invalid:2666.09.13 \
  DHYDRO.SharedConfigurations:6.6.6.666 \
  NUnit:3.12.6"
git add ${dir_package_rops_file}
git commit -m 'Update dependencies versions'
git push -u origin ${release_branch}

# release has now diverged from the base branch, cerate a PR
gh pr create \
--base ${base_branch} \
--head ${release_branch} \
--title "Release ${tag}" \
--fill

# create tagged release from the release branch, set title same as tag, autogenerate the release notes and make set it to latest
gh release create ${tag} \
--repo github.com/Deltares-research/MeshKernelReleaseAutomation \
--target ${release_branch} \
--title ${tag} \
--generate-notes  \
--latest

# checkout the base branch, fetch everything, we care about the base branch and the latest release tag 
git checkout ${base_branch}
git fetch --all
git pull

# merge the tag into the base branch then push to remote
git merge --no-ff ${tag}
git push -u origin ${base_branch}

# log out
gh auth logout

set +x