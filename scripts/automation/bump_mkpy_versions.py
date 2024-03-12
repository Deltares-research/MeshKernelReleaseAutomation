import re
import argparse
import sys
from pathlib import Path


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

    parser.add_argument(
        "--to_backend_version",
        type=str,
        required=True,
        help="New MeshKernel (backend) version",
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


def check_new_versions(version: str, backend_version: str):
    if not is_semantic_version(version):
        raise Exception(version + " is not a valid semantic version")
    if not is_semantic_version(backend_version):
        raise Exception(backend_version + " is not a valid semantic version")


def bump_mkpy_versions(version_file, new_version, new_backend_version):
    """
    Update the __version__ and __backend_version__ variables in the version.py file.

    Args:
    - version_file (str): Path to the version.py file.
    - new_version (str): The new version to set for __version__.
    - new_backend_version (str): The new version to set for __backend_version__.

    Returns:
    - bool: True if the versions were updated successfully, False otherwise.
    """
    # Open the version.py file in read mode
    with open(version_file, "r") as f:
        lines = f.readlines()

    # Update the variables if found
    updated_lines = []
    for line in lines:
        if line.startswith("__version__"):
            updated_lines.append(f'__version__ = "{new_version}"\n')
        elif line.startswith("__backend_version__"):
            updated_lines.append(f'__backend_version__ = "{new_backend_version}"\n')
        else:
            updated_lines.append(line)

    # Write the updated content back to the file
    with open(version_file, "w") as f:
        f.writelines(updated_lines)

    return True


if __name__ == "__main__":
    version = str()
    try:
        args = parse_args()
        check_new_versions(args.to_version, args.to_backend_version)
        bump_mkpy_versions(args.file, args.to_version, args.to_backend_version)
    except Exception as error:
        print("Error:", error, file=sys.stderr)
