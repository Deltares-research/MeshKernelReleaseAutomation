"""
Pins and tags a NuGet package on TeamCity. Removes the tag, if found, from a previous 
build and removes the pin when possible.
"""

import argparse
import logging
import sys
from typing import Dict, Optional, Sequence

from request_wrapper import BUILDS_ROOT, RequestWrapper


def get_previous_build(
    branch_name: str, build_config_id: str, tag: str, wrapper: RequestWrapper
) -> Optional[Dict]:
    """
    Get the previous build tagged with the specified tag

    Args:
        build_config : str
            The build configuration id of the build to be retrieved.
        tag : str
            The tag with which the build should be retrieved.
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """

    build_url = f"{BUILDS_ROOT}?locator=branch:{branch_name},buildType:{build_config_id},tag:{tag},pinned:true,count:1"

    print(build_url)

    response = wrapper.get(build_url)

    if response.status_code != 200:
        return None

    if response.json()["count"] == 0:
        return None

    build_id = response.json()["build"][0]["id"]
    build_url_by_id = f"{BUILDS_ROOT}/id:{build_id}"
    response_by_id = wrapper.get(build_url_by_id)
    if response.status_code != 200:
        return None

    return response_by_id.json()


def unpin_build(build_id: str, wrapper: RequestWrapper) -> None:
    """
    Unpin the build with build_id.

    Args:
        build_id : str
            The id of the build to be unpinned.
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    pin_url = f"{BUILDS_ROOT}/id:{build_id}/pin/"
    wrapper.delete(pin_url)


def clean_build(build_info: dict, tag: str, wrapper: RequestWrapper) -> None:
    """
    Remove the specified tag from the specified build and unpin if necessary.

    Args:
        build_info : dict
            A dictionary describing the build to be modified.
        tag : str
            The tag to be removed from the build
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """

    untag_build(build_info, tag, wrapper)
    tag_info = build_info["tags"]
    if tag in get_tag_values(tag_info) and tag_info["count"] == 1:
        build_id = build_info["id"]
        unpin_build(build_id, wrapper)


def get_tag_values(tags) -> Sequence[str]:
    """
    Get the tags from the specified tags dictionary.

    Args:
        tags : dict
            A tags dictionary.
    """
    return list(x["name"] for x in tags["tag"])


def untag_build(build_info: dict, tag: str, wrapper: RequestWrapper) -> None:
    """
    Remove the specified tag from the build specified with build_info.

    Args:
        build_info : dict
            A dictionary describing the build to be modified.
        tag : str
            The tag to be removed from the build
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    build_tags = get_tag_values(build_info["tags"])
    if tag not in build_tags:
        return

    new_tag_values = list({"name": x} for x in build_tags if x != tag)
    new_tags = {"count": len(new_tag_values), "tag": new_tag_values}

    tag_url = f"{BUILDS_ROOT}/id:{build_info['id']}/tags/"
    wrapper.put_json(tag_url, new_tags)


def has_artifact_for_nuget_pkg(
    build_url: str, artifact_name: str, wrapper: RequestWrapper
) -> bool:
    """
    Returns whether or not the specified build has the valid
    artifact for the nuget package

    Args:
        build_url : str
            The build url to check the artifacts for.
        artifact_name : str
            The expected artifact file name within the build to be retrieved.
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    build_artifacts_url = f"{build_url}artifacts/"
    artifacts_response = wrapper.get(build_artifacts_url)

    if artifacts_response.status_code != 200:
        return False

    return artifact_name in (elem["name"] for elem in artifacts_response.json()["file"])


def get_new_build(
    branch_name: str, build_config_id: str, artifact_name: str, wrapper: RequestWrapper
) -> Optional[Dict]:
    """
    Get the build from build_config with the specified nuget package file.

    Args:
        build_config_id : str
            The id of the build configuration of which the build is part.
        artifact_name : str
            The expected nuget package file name within the build to be retrieved.
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    builds_url = (
        f"{BUILDS_ROOT}?locator=branch:{branch_name},buildType:{build_config_id}"
    )

    new_builds_response = wrapper.get(builds_url)

    if new_builds_response.status_code != 200:
        return None

    builds = new_builds_response.json()
    for build in builds["build"]:

        new_build_url = f"{BUILDS_ROOT}/id:{build['id']}/"

        if not has_artifact_for_nuget_pkg(new_build_url, artifact_name, wrapper):
            continue

        new_build_info = wrapper.get(new_build_url)

        if new_build_info.status_code != 200:
            logging.warning(
                f"Request '{new_build_url}' returned {new_build_info.status_code}."
            )
            continue

        return new_build_info.json()

    return None


def pin_build(build_id: str, wrapper: RequestWrapper) -> None:
    """
    Pin the build with build_id.

    Args:
        build_id : str
            The id of the build to be pinned.
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    pin_url = f"{BUILDS_ROOT}/id:{build_id}/pin/"
    wrapper.put(pin_url)


def tag_build(build_info, tag: str, wrapper: RequestWrapper) -> None:
    """
    Add a tag with value tag to the build specified with build_info.

    Args:
        build_info : dict
            A dictionary describing the build to be modified.
        tag : str
            The new tag to be added to the build
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    if "tags" in build_info:
        new_tag_values = list(
            {"name": x} for x in get_tag_values(build_info["tags"]) if x != tag
        )
    else:
        new_tag_values = []

    new_tag_values.append({"name": tag})

    new_tags = {"count": len(new_tag_values), "tag": new_tag_values}

    tag_url = f"{BUILDS_ROOT}/id:{build_info['id']}/tags/"
    wrapper.put_json(tag_url, new_tags)


def bag_build(build_info: dict, tag: str, wrapper: RequestWrapper) -> None:
    """
    Pin and tag the build specified with build_info.

    Args:
        build_info : dict
            A dictionary describing the build to be modified.
        tag : str
            The new tag to be added to the build
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """
    pin_build(build_info["id"], wrapper)
    tag_build(build_info, tag, wrapper)


def pin_nuget_package(
    branch_name: str,
    artifact_name: str,
    build_config_id: str,
    tag: str,
    wrapper: RequestWrapper,
):
    """
    Pin and tag the build specified with build_info.

    Args:
        artifact_name : str
            The expected name of the published artifact.
        build_id : str
            The id of the build configuration on TeamCity that publishes the specified NuGet package.
        tag : str
            The new tag to be added to the build
        wrapper : RequestWrapper
            The request wrapper to make requests calls.
    """

    old_build_info = get_previous_build(branch_name, build_config_id, tag, wrapper)
    if old_build_info:
        clean_build(old_build_info, tag, wrapper)

    new_build_info = get_new_build(branch_name, build_config_id, artifact_name, wrapper)
    if new_build_info:
        bag_build(new_build_info, tag, wrapper)
    else:
        logging.warning(
            f"Could not find a build to tag NuGet package '{artifact_name}'."
        )


def get_version(version: str) -> str:
    """Removes the leading zeros from the version string when version is a digit"""
    return ".".join(str(int(x)) if x.isdigit() else x for x in version.split("."))


def parse_arguments():
    """
    Parse the arguments with which this script was called through
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--branch_name",
        type=str,
        required=True,
        help="The branch name.",
    )

    parser.add_argument(
        "--artifact_name",
        type=str,
        required=True,
        help="The name of the artifact to pin and tag.",
    )

    parser.add_argument(
        "--build_config_id",
        type=str,
        required=True,
        help="The id of the build configuration on TeamCity that publishes the specified NuGet package.",
    )

    parser.add_argument(
        "--tag",
        type=str,
        required=True,
        help="The tag to pin the build of the specified NuGet package with.",
    )

    parser.add_argument(
        "--teamcity_access_token",
        type=argparse.FileType("r"),
        required=True,
        help="The TeamCity access token to authenticate with.",
    )

    return parser.parse_args()


def run(
    branch_name: str,
    artifact_name: str,
    build_config_id: str,
    tag: str,
    teamcity_access_token: str,
):
    """
    Runs the script with the specified parameters.

    Args:
        branch_name: str
            The name of the branch.
        nuget_name : str
            The name of the NuGet package to pin and tag.
        nuget_version : str
            The version of the NuGet package to pin and tag.
        build_id : str
            The id of the build configuration on TeamCity that publishes the specified NuGet package.
        tag : str
            The tag to pin the build of the specified NuGet package with.
        user : str
            The user to authenticate with.
        password : str
            The password to authenticate with.
    """

    wrapper = RequestWrapper(teamcity_access_token)
    pin_nuget_package(branch_name, artifact_name, build_config_id, tag, wrapper)


if __name__ == "__main__":
    try:
        args = parse_arguments()

        run(
            args.branch_name,
            args.artifact_name,
            args.build_config_id,
            args.tag,
            args.teamcity_access_token.read(),
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
