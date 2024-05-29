import argparse
import sys
from pathlib import Path

from versioning import check_semantic_version


def parse_args():
    """
    Parse the arguments with which this script is called
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--file",
        "-f",
        type=Path,
        required=True,
        help="Path to the nuspec file to parse.",
    )

    parser.add_argument(
        "--to_version",
        type=str,
        required=True,
        help="New MeshKernelPy version",
    )

    args = parser.parse_args()

    return args


def bump_mk_version(cmakelists_file, new_version):
    """
    Update the project version in the root CMakeLists.txt.

    Args:
    - cmakelists_file (str): Path to the version.py file.
    - new_version (str): The new version to set for __version__.

    Returns:
    - bool: True if the versions were updated successfully, False otherwise.
    """
    # Open the version.py file in read mode
    with open(cmakelists_file, "r") as f:
        lines = f.readlines()

    # Update the variables if found
    updated_lines = []
    for line in lines:
        if line.startswith("set(MESHKERNEL_VERSION"):
            updated_lines.append(f"set(MESHKERNEL_VERSION {new_version})\n")
        else:
            updated_lines.append(line)

    # Write the updated content back to the file
    with open(cmakelists_file, "w") as f:
        f.writelines(updated_lines)

    return True


if __name__ == "__main__":
    version = str()
    try:
        args = parse_args()
        check_semantic_version(args.to_version)
        bump_mk_version(args.file, args.to_version)
    except Exception as error:
        print("Error:", error, file=sys.stderr)
