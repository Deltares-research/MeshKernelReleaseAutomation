import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def parse_args() -> Path:
    """
    Parse the arguments with which this script is called
    """
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--nuspec_file",
        type=Path,
        required=True,
        help="Path to the nuspec file.",
    )

    parser.add_argument(
        "--dir_build_props_file",
        type=Path,
        required=True,
        help="Path to the Directory.Build.Props file.",
    )

    parser.add_argument(
        "--version_tag",
        type=str,
        required=True,
        help="T.",
    )

    parser.add_argument(
        "--to_version",
        type=str,
        required=True,
        help="New version.",
    )

    return parser.parse_args()


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
    return (match is not None) and (len(match.groups()) == 3)


def check_new_version(version: str):
    if not is_semantic_version(version):
        raise Exception(version + " is not a valid semantic version")


def bump_nuspec_version(nuspec_file: Path, to_version: str):
    """
    Bumps the version in the nuspec configuration.
    Ars:
    """

    # Parse the XML file
    tree = ET.parse(nuspec_file)

    # Get the root node
    root = tree.getroot()

    # Extract the namespace from the root element
    namespace = root.tag.split("}")[0][1:]

    ET.register_namespace("", namespace)

    # Find the version element
    version = root.find(".//{%s}metadata/{%s}version" % (namespace, namespace))

    if version is not None:
        version.text = to_version
        tree.write(nuspec_file, xml_declaration=True, encoding="utf-8", method="xml")
    else:
        raise Exception(
            "Could not find metadata/version element in " + str(nuspec_file)
        )


def bump_dir_build_props_version(
    dir_build_props_file: Path, version_tag: str, to_version: str
):
    """
    Get the nuspec version by parsing a nuspec file
    """

    # Parse the XML file
    tree = ET.parse(dir_build_props_file)

    # Get the root node
    root = tree.getroot()

    # Find the version element
    version = root.find("./PropertyGroup/" + version_tag)

    if version is not None:
        version.text = to_version
        tree.write(dir_build_props_file, encoding="utf-8", method="xml")
    else:
        raise Exception(
            "Could not find version element in " + str(dir_build_props_file)
        )


if __name__ == "__main__":
    try:
        args = parse_args()
        check_new_version(args.to_version)
        bump_nuspec_version(args.nuspec_file, args.to_version)
        bump_dir_build_props_version(
            args.dir_build_props_file, args.version_tag, args.to_version
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
