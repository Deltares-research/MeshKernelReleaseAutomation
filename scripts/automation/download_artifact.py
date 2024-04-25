import argparse
import os
import sys
from pathlib import Path

from request_wrapper import DOWNLOADS_ROOT, RequestWrapper


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
        help="The id of the build configuration on TeamCity that publishes the specified artifact.",
    )

    parser.add_argument(
        "--tag",
        type=str,
        required=True,
        help="The tag to pin the build of the specified artifact with.",
    )

    parser.add_argument(
        "--destination",
        "-f",
        type=Path,
        required=True,
        help="Path where the wheels are to be saved.",
    )
    parser.add_argument(
        "--teamcity_access_token",
        type=argparse.FileType("r"),
        required=True,
        help="The TeamCity access token to authenticate with.",
    )

    return parser.parse_args()


def download_artifact(
    branch_name: str,
    artifact_name: str,
    build_config_id: str,
    tag: str,
    destination: Path,
    request: RequestWrapper,
):
    """
    Args:
       branch_name: str
           The name of the branch.
       artifact_name : str
           The name of the artifact to pin and tag.
       build_config_id : str
           The id of the build configuration on TeamCity that publishes the specified artifact.
       tag : str
           The tag to pin the build of the specified artifact with.
       request : RequestWrapper
           The request.
    """
    url = (
        f"{DOWNLOADS_ROOT}/"
        f"{build_config_id}/"
        f"{tag}.tcbuildtag/"
        f"{artifact_name}?"
        f"branch={branch_name}"
    )
    response = request.get(url)
    path = os.path.join(destination, artifact_name)
    with open(path, "wb") as wheel:
        for chunk in response.iter_content(chunk_size=256):
            wheel.write(chunk)


def run(
    branch_name: str,
    artifact_name: str,
    build_config_id: str,
    tag: str,
    destination: Path,
    teamcity_access_token: str,
):
    """
    Runs the script with the specified parameters.

    Args:
        branch_name: str
            The name of the branch.
        artifact_name : str
            The name of the artifact to pin and tag.
        build_config_id : str
            The id of the build configuration on TeamCity that publishes the specified artifact.
        tag : str
            The tag to pin the build of the specified artifact with.
        teamcity_access_token : str
            The TeamCity access token to authenticate with.
    """
    request = RequestWrapper(teamcity_access_token)
    download_artifact(
        branch_name, artifact_name, build_config_id, tag, destination, request
    )


if __name__ == "__main__":
    try:
        args = parse_arguments()
        run(
            args.branch_name,
            args.artifact_name,
            args.build_config_id,
            args.tag,
            args.destination,
            args.teamcity_access_token.read(),
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
