import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from versioning import check_semantic_version


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
        check_semantic_version(args.to_version)
        bump_nuspec_version(args.nuspec_file, args.to_version)
        bump_dir_build_props_version(
            args.dir_build_props_file, args.version_tag, args.to_version
        )
    except Exception as error:
        print("Error:", error, file=sys.stderr)
