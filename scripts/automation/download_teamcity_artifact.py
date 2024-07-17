import argparse
import os
import sys
from pathlib import Path

from request_wrapper import BUILDS_ROOT, DOWNLOADS_ROOT, RequestsWrapper


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
        help="The name of the artifact to download.",
    )

    parser.add_argument(
        "--artifact_path",
        type=str,
        required=False,
        default="",
        help="The path of the artifact to download. If not specified, the TeamCity root download dir is assumed.",
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


def download_teamcity_artifact(
    branch_name: str,
    artifact_name: str,
    build_config_id: str,
    tag: str,
    destination: Path,
    request: RequestsWrapper,
    artifact_path: str = "",
):
    # Get the build ID
    params = {
        "locator": f"branch:{branch_name},buildType:{build_config_id},tags:{tag},count:1"
    }

    headers = {"Accept": "application/json"}

    response = request.get(BUILDS_ROOT, params=params, headers=headers)

    if response.status_code != 200:
        raise Exception(f"Failed to get build ID: {response.text}")

    builds = response.json().get("build", [])

    build_id = builds[0]["id"]

    # Download the artifact
    artifact_url = f"{DOWNLOADS_ROOT}/{build_config_id}/{build_id}:id"
    if artifact_path:
        artifact_url = f"{artifact_url}/{artifact_path}"
    artifact_url = f"{artifact_url}/{artifact_name}"

    response = request.get(artifact_url, headers=headers)

    # Write artifact to destination
    path = os.path.join(destination, artifact_name)
    with open(path, "wb") as artifact:
        for chunk in response.iter_content(chunk_size=256):
            artifact.write(chunk)

    print(f"Artifact {artifact_name} downloaded successfully to {destination}")


def run(
    branch_name: str,
    artifact_name: str,
    build_config_id: str,
    tag: str,
    destination: Path,
    teamcity_access_token: str,
    artifact_path: str = "",
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
    request = RequestsWrapper(teamcity_access_token)
    download_teamcity_artifact(
        branch_name,
        artifact_name,
        build_config_id,
        tag,
        destination,
        request,
        artifact_path=artifact_path,
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
            args.artifact_path,
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
