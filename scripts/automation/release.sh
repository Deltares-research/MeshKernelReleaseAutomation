#!/bin/bash

set -x

commit_id=
gh_refresh_interval=30 # seconds
wait=${refresh_interval}

function usage {
    echo "Usage: $0 --version string --base_branch string --gh_token string "
    echo "Creates a new release"
    echo ""
    echo "  --version              Required  string   Version of new release"
    echo "  --base_branch          Required  string   Base branch"
    echo "  --commit_id            Optional  string   ID of commit check out"
    echo "                                            If provided, it should belong to the specified base branch. "
    echo "                                            Otherwise the HEAD of  the base branch is checked out."
    echo "  --gh_token             Required  string   Path to github token"
    echo "  --gh_refresh_interval  Optional  integer  Refresh interval in seconds "
    echo "                                            Used as a refresh interval while watching github PR checks, default = 30s"
    echo "  --wait                 Optional  integer  Wait duration in seconds"
    echo "                                            The script sleeps for this duration before watching github PR checks, default = 30s"
    echo ""
}

function die {
    printf "Script failed: %s\n" "$1"
    usage
    exit 1
}

error() {
    # store last exit code before invoking any other command
    local exit_code="$?"
    # print error message
    echo Error: "$1"
    exit $exit_code
}

while [ $# -gt 0 ]; do
    if [[ $1 == "--help" ]]; then
        usage
        exit 0
    elif [[ $1 == "--"* ]]; then
        v="${1/--/}"
        declare "$v"="$2"
        shift
    fi
    shift
done

if [[ -z ${version} ]]; then
    die "Missing parameter --version"
elif [[ -z ${base_branch} ]]; then
    die "Missing parameter --base_branch"
elif [[ -z ${gh_token} ]]; then
    die "Missing parameter --gh_token"
fi

tag=v${version}
release_branch=release/${tag}

scripts_dir=.
root_dir=../..
python_version_file=${root_dir}/python/version.py
nuspec_file=${root_dir}/nuget/MeshKernelReleaseAutomation.nuspec
dir_build_props_file=${root_dir}/Directory.Build.props
dir_package_props_file=${root_dir}/Directory.Packages.props

repo=github.com/Deltares-research/MeshKernelReleaseAutomation

# login
gh auth login --with-token <${gh_token}

# fetch master
git fetch origin ${base_branch}
git branch --contains ${commit_id} | grep --quiet ${base_branch}
if [ $? -eq 0 ]; then
    git checkout -B ${release_branch} ${commit_id}
else
    git checkout -B ${release_branch} ${base_branch}
fi
git push -f origin ${release_branch}

# update version of python bindings
python ${scripts_dir}/bump_mkpy_versions.py \
    --file ${python_version_file} \
    --to_version ${version} \
    --to_backend_version ${version}
git add ${python_version_file}
git commit -m 'Update python bindings version'
git push -u origin ${release_branch}

# release has now diverged from the base branch, create a PR
gh pr create \
    --repo ${repo} \
    --base ${base_branch} \
    --head ${release_branch} \
    --title "Release ${tag}" \
    --fill

sleep ${wait}
gh pr checks ${release_branch} \
    --repo ${repo} \
    --watch \
    --interval ${gh_refresh_interval} ||
    error "One or more checks failed"

# update product version
python ${scripts_dir}/bump_package_version.py \
    --nuspec_file ${nuspec_file} \
    --dir_build_props_file ${dir_build_props_file} \
    --version_tag "MeshKernelReleaseAutomationVersion" \
    --to_version ${version}
git add ${nuspec_file} ${dir_build_props_file}
git commit -m 'update product version'
git push -u origin ${release_branch}

sleep ${wait}
gh pr checks ${release_branch} \
    --repo ${repo} \
    --watch \
    --interval ${gh_refresh_interval} ||
    error "One or more checks failed"

# update versions of dependencies
python ${scripts_dir}/bump_dependencies_versions.py \
    --dir_packages_props_file ${dir_package_props_file} \
    --to_versioned_packages \
    "Deltares.MeshKernel:${version} \
  Invalid:2666.09.13 \
  DHYDRO.SharedConfigurations:6.6.6.666 \
  NUnit:3.12.6"
git add ${dir_package_props_file}
git commit -m 'Update dependencies versions'
git push -u origin ${release_branch}

sleep ${wait}
gh pr checks ${release_branch} \
    --repo ${repo} \
    --watch \
    --interval ${gh_refresh_interval} ||
    error "One or more checks failed"

# create tagged release from the release branch, set title same as tag, autogenerate the release notes and make set it to latest
gh release create ${tag} \
    --repo ${repo} \
    --target ${release_branch} \
    --title ${tag} \
    --generate-notes \
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
