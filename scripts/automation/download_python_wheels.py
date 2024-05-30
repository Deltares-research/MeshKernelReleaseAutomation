import argparse
import sys
from pathlib import Path

from download_artifact import run
from versioning import check_semantic_version


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


def download_python_wheels(
    version: str,
    destination: Path,
    teamcity_access_token: str,
):
    """
    Downloads python wheels from TeamCity (Windows and Linux wheels only, macOS wheels are built on github).

    Args:
    - version (str): The wheel version.
    - destination (Path): Path where the wheels are to be saved.
    - teamcity_access_token (str): The TeamCity access token to authenticate with.
    """

    tag = f"v{version}"
    branch = f"release/v{version}"

    build_configs = {
        "Windows": "win_amd64",
        "Linux": "manylinux_2_17_x86_64.manylinux2014_x86_64",
    }

    for platform, arch in build_configs.items():
        artifact = f"meshkernel-{version}-py3-none-{arch}.whl"
        build_config_id = f"GridEditor_MeshKernelPy_{platform}_BuildPythonWheel"
        run(
            branch,
            artifact,
            build_config_id,
            tag,
            destination,
            teamcity_access_token,
        )


if __name__ == "__main__":
    try:
        args = parse_args()
        check_semantic_version(args.version)
        download_python_wheels(
            args.version,
            args.destination,
            args.teamcity_access_token.read(),
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
