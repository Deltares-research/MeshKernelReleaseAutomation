#!/bin/bash

set -x

gh_refresh_interval=30 # seconds
wait=${refresh_interval}

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

if git show-ref --tags --verify --quiet -- refs/tags/${start_point} >/dev/null 2>&1; then
    echo ${start_point} is a tag
elif git show-ref --verify --quiet -- refs/heads/${start_point} >/dev/null 2>&1; then
    echo ${start_point} is a branch
elif git rev-parse --verify ${start_point}^{commit} >/dev/null 2>&1; then
    echo ${start_point} is a commit
else
    error ${start_point} is neither a commit ID, a tag, nor a branch
fi

# pull remote
git pull origin ${start_point}

# switch to release branch
git checkout -B ${release_branch} ${start_point}

# and immediately push it to remote
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
git merge --no-ff ${tag} || error "Merge tag failed highly likely due to merge conflicts"
git push -u origin ${base_branch}

# log out
gh auth logout

set +x
