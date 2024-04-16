import argparse
import os
import re
import sys
from pathlib import Path

import requests


def parse_args():
    """
    Parse the arguments with which this script is called
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--version",
        type=str,
        required=True,
        help="The wheel version",
    )

    parser.add_argument(
        "--teamcity_access_token",
        type=argparse.FileType("r"),
        required=True,
        help="The TeamCity access token to authenticate with.",
    )

    parser.add_argument(
        "--destination",
        "-f",
        type=Path,
        required=True,
        help="Path where the wheels are to be saved.",
    )

    args = parser.parse_args()

    return args


def is_semantic_version(version_string):
    """
    Check if a string corresponds to a semantic version.

    Args:
    - version_string (str): The string to be checked.

    Returns:
    - bool: True if the string corresponds to a semantic version, False otherwise.
    """
    # Semantic version regex pattern
    pattern = r"^(\d+)\.(\d+)\.(\d+)$"

    # Compile the regex pattern
    regex = re.compile(pattern)

    # Match the version string against the pattern
    match = regex.match(version_string)

    # If match is found and there are 3 groups corresponding to major, minor, and patch versions
    return match and len(match.groups()) == 3


def check_version(version: str):
    if not is_semantic_version(version):
        raise Exception(version + " is not a valid semantic version")


def download_python_wheels(
    version: str,
    teamcity_access_token: str,
    destination: Path,
):
    """
    Downloads python wheels from TeamCity (Windows and Linux wheels only, macOS wheels are built on github).

    Args:
    - version (str): The wheel version.
    - teamcity_access_token (str): The TeamCity access token to authenticate with.
    - destination (Path): Path where the wheels are to be saved.
    """

    build_tag = f"v{version}"
    branch = f"release/v{version}"

    platform_dict = {
        "Windows": "win_amd64",
        "Linux": "manylinux_2_17_x86_64.manylinux2014_x86_64",
    }

    HEADERS = {
        "Authorization": f"Bearer {teamcity_access_token}",
        "Content-Type": "application/json",
    }

    for platform, arch in platform_dict.items():
        artifact = f"meshkernel-{version}-py3-none-{arch}.whl"
        URL = (
            "https://dpcbuild.deltares.nl/repository/download/"
            f"GridEditor_MeshKernelPy_{platform}_BuildPythonWheel/"
            f"{build_tag}.tcbuildtag/{artifact}?branch={branch}"
        )
        response = requests.get(url=URL, headers=HEADERS)
        response.raise_for_status()
        path = os.path.join(destination, artifact)
        with open(path, "wb") as wheel:
            for chunk in response.iter_content(chunk_size=256):
                wheel.write(chunk)
        response.close()


if __name__ == "__main__":
    try:
        args = parse_args()
        check_version(args.version)
        download_python_wheels(
            args.version,
            args.teamcity_access_token.read(),
            args.destination,
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
